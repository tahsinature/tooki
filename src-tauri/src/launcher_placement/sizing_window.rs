use super::{
    geometry::{self, Point},
    persistence, sizing, work, Placement,
};
use tauri::{LogicalPosition, Manager, WebviewWindow};

pub fn remember_size(window: &WebviewWindow) -> Result<(), String> {
    let size = window
        .inner_size()
        .map_err(|e| e.to_string())?
        .to_logical::<f64>(window.scale_factor().map_err(|e| e.to_string())?);
    let changed = window
        .state::<Placement>()
        .sizing
        .lock()
        .map_err(|e| e.to_string())?
        .capture(sizing::Size {
            width: size.width,
            height: size.height,
        });
    if changed {
        persistence::save(window)?;
    }
    Ok(())
}
pub fn remember(app: &tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        if let Err(error) = remember_size(&window) {
            eprintln!("Could not save launcher size: {error}");
        }
    }
}
pub fn requested_size(
    window: &WebviewWindow,
    mode: sizing::Mode,
    header_height: f64,
) -> Result<sizing::Size, String> {
    remember_size(window)?;
    let available = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .or(window.primary_monitor().map_err(|e| e.to_string())?)
        .map(|m| {
            let area = work(&m);
            sizing::Size {
                width: area.width,
                height: area.height,
            }
        })
        .unwrap_or(sizing::Size {
            width: f64::MAX,
            height: f64::MAX,
        });
    let state = window.state::<Placement>();
    let mut sizing = state.sizing.lock().map_err(|e| e.to_string())?;
    let target = sizing.target(mode, header_height, available);
    // Hiding during an in-flight layout must not record that layout as a user resize.
    sizing.applied = None;
    Ok(target)
}
pub fn applied_size(window: &WebviewWindow, mode: sizing::Mode) -> Result<(), String> {
    let actual = window
        .inner_size()
        .map_err(|e| e.to_string())?
        .to_logical::<f64>(window.scale_factor().map_err(|e| e.to_string())?);
    window
        .state::<Placement>()
        .sizing
        .lock()
        .map_err(|e| e.to_string())?
        .applied = Some((
        mode,
        sizing::Size {
            width: actual.width,
            height: actual.height,
        },
    ));
    // A wider/taller restored window must still fit the current display.
    if let Some(monitor) = window.current_monitor().map_err(|e| e.to_string())? {
        let position = window
            .outer_position()
            .map_err(|e| e.to_string())?
            .to_logical::<f64>(window.scale_factor().map_err(|e| e.to_string())?);
        let fitted = geometry::clamp(
            Point {
                x: position.x,
                y: position.y,
            },
            work(&monitor),
            actual.width,
            actual.height,
        );
        if fitted.x != position.x || fitted.y != position.y {
            window
                .set_position(LogicalPosition::new(fitted.x, fitted.y))
                .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}
