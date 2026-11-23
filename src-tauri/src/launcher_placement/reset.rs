use super::{
    persistence,
    sizing::{Mode, Size},
    work, Placement,
};
use tauri::{LogicalPosition, LogicalSize, Manager};

#[tauri::command]
pub async fn reset_launcher_layout(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<(), String> {
    if window.label() != "settings" {
        return Err("Reset launcher layout from Settings.".into());
    }
    let (sender, receiver) = tokio::sync::oneshot::channel();
    let handle = app.clone();
    app.run_on_main_thread(move || {
        let _ = sender.send(reset(&handle));
    })
    .map_err(|error| error.to_string())?;
    receiver.await.map_err(|error| error.to_string())?
}

fn reset(app: &tauri::AppHandle) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or("Launcher is unavailable.")?;
    let monitor = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .or(window.primary_monitor().map_err(|e| e.to_string())?)
        .ok_or("No display available.")?;
    let area = work(&monitor);
    let state = app.state::<Placement>();
    let previous = state.sizing.lock().map_err(|e| e.to_string())?.applied;
    let (mode, mut size) = reset_size(previous);
    size = size.fit(Size {
        width: area.width,
        height: area.height,
    });
    // Do not interpret this programmatic resize as a user preference change.
    state.sizing.lock().map_err(|e| e.to_string())?.applied = None;
    window
        .set_size(LogicalSize::new(size.width, size.height))
        .map_err(|e| e.to_string())?;
    window
        .set_position(LogicalPosition::new(
            area.x + (area.width - size.width) / 2.0,
            area.y + (area.height - size.height) / 2.0,
        ))
        .map_err(|e| e.to_string())?;
    {
        let mut sizing = state.sizing.lock().map_err(|e| e.to_string())?;
        sizing.preferred = Size::default();
        sizing.applied = Some((mode, size));
    }
    persistence::save(&window)
}

fn reset_size(previous: Option<(Mode, Size)>) -> (Mode, Size) {
    let mut size = Size::default();
    let mode = previous.map_or(Mode::Expanded, |(mode, _)| mode);
    if let Some((Mode::Compact, applied)) = previous {
        size.height = applied.height;
    }
    (mode, size)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reset_preserves_compact_presentation_but_removes_custom_dimensions() {
        let custom = Size {
            width: 1100.0,
            height: 100.0,
        };
        let (mode, size) = reset_size(Some((Mode::Compact, custom)));
        assert_eq!(mode, Mode::Compact);
        assert_eq!(size.width, Size::default().width);
        assert_eq!(size.height, 100.0);
        assert_eq!(
            reset_size(Some((Mode::Expanded, custom))),
            (Mode::Expanded, Size::default())
        );
        assert_eq!(reset_size(None), (Mode::Expanded, Size::default()));
    }
}
