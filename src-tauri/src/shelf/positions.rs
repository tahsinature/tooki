//! Floating Shelf positions are independent of launcher geometry and survive display changes.
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, path::PathBuf, sync::Mutex};
use tauri::{Manager, PhysicalPosition};
#[derive(Clone, Serialize, Deserialize)]
struct Position {
    monitor: Option<String>,
    x: f64,
    y: f64,
}
#[derive(Default)]
struct State {
    positions: BTreeMap<String, Position>,
    revision: u64,
}
#[derive(Default)]
pub struct Positions(Mutex<State>);
fn path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("shelf-positions.json"))
}
pub fn initialize(app: &tauri::AppHandle) {
    let result = (|| -> Result<(), String> {
        let path = path(app)?;
        if path.exists() {
            let positions =
                serde_json::from_slice(&std::fs::read(path).map_err(|e| e.to_string())?)
                    .map_err(|e| e.to_string())?;
            app.state::<Positions>()
                .0
                .lock()
                .map_err(|e| e.to_string())?
                .positions = positions;
        }
        Ok(())
    })();
    if let Err(e) = result {
        eprintln!("Shelf positions: {e}");
    }
}
fn write(app: &tauri::AppHandle, state: &State) -> Result<(), String> {
    let path = path(app)?;
    let temp = path.with_extension("tmp");
    std::fs::write(
        &temp,
        serde_json::to_vec(&state.positions).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    // rename replaces the destination atomically on Unix.
    #[cfg(windows)]
    if path.exists() {
        std::fs::remove_file(&path).map_err(|e| e.to_string())?;
    }
    std::fs::rename(temp, path).map_err(|e| e.to_string())
}
pub fn flush(app: &tauri::AppHandle) {
    if let Ok(state) = app.state::<Positions>().0.lock() {
        if let Err(e) = write(app, &state) {
            eprintln!("Shelf position save: {e}");
        }
    }
}
pub fn handle_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    let Some(id) = window.label().strip_prefix("shelf-") else {
        return;
    };
    let tauri::WindowEvent::Moved(pos) = event else {
        return;
    };
    if !window.is_visible().unwrap_or(false) {
        return;
    }
    let Ok(Some(monitor)) = window.current_monitor() else {
        return;
    };
    let work = monitor.work_area();
    let position = Position {
        monitor: monitor.name().cloned(),
        x: (pos.x - work.position.x) as f64 / work.size.width as f64,
        y: (pos.y - work.position.y) as f64 / work.size.height as f64,
    };
    let app = window.app_handle().clone();
    let revision = {
        let state = app.state::<Positions>();
        let Ok(mut state) = state.0.lock() else {
            return;
        };
        state.positions.insert(id.into(), position);
        state.revision += 1;
        state.revision
    };
    tauri::async_runtime::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_millis(300)).await;
        let state = app.state::<Positions>();
        if let Ok(state) = state.0.lock() {
            if state.revision == revision {
                if let Err(e) = write(&app, &state) {
                    eprintln!("Shelf position save: {e}");
                }
            }
        };
    });
}
pub fn restore(window: &tauri::WebviewWindow, id: &str) -> Result<(), String> {
    let saved = window
        .state::<Positions>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .positions
        .get(id)
        .cloned();
    let Some(saved) = saved else {
        let pointer = window
            .app_handle()
            .cursor_position()
            .map_err(|e| e.to_string())?;
        let monitor = window
            .app_handle()
            .monitor_from_point(pointer.x, pointer.y)
            .map_err(|e| e.to_string())?;
        if let Some(monitor) = monitor {
            let work = monitor.work_area();
            let scale = monitor.scale_factor();
            let neighbour = window
                .app_handle()
                .webview_windows()
                .into_iter()
                .filter(|(label, w)| {
                    label.starts_with("shelf-")
                        && label != window.label()
                        && w.is_visible().unwrap_or(false)
                })
                .filter_map(|(_, w)| w.outer_position().ok())
                .min_by_key(|p| p.x);
            let (x, y) = neighbour
                .map(|p| (p.x as f64 - 312. * scale, p.y as f64))
                .unwrap_or((
                    work.position.x as f64 + work.size.width as f64 - 324. * scale,
                    work.position.y as f64 + 24. * scale,
                ));
            window
                .set_position(PhysicalPosition::new(
                    x.clamp(
                        work.position.x as f64,
                        (work.position.x as f64 + work.size.width as f64 - 300. * scale)
                            .max(work.position.x as f64),
                    ) as i32,
                    y.clamp(
                        work.position.y as f64,
                        (work.position.y as f64 + work.size.height as f64 - 160. * scale)
                            .max(work.position.y as f64),
                    ) as i32,
                ))
                .map_err(|e| e.to_string())?;
        }
        return Ok(());
    };
    if !saved.x.is_finite() || !saved.y.is_finite() {
        return Err("Invalid saved Shelf position".into());
    }
    let monitors = window.available_monitors().map_err(|e| e.to_string())?;
    let primary = window.primary_monitor().map_err(|e| e.to_string())?;
    let Some(m) = monitors
        .iter()
        .find(|m| m.name().cloned() == saved.monitor)
        .or(primary.as_ref())
    else {
        return Ok(());
    };
    let work = m.work_area();
    let scale = m.scale_factor();
    let x = clamp_axis(
        work.position.x,
        work.size.width,
        saved.x,
        (300. * scale) as u32,
    );
    let y = clamp_axis(
        work.position.y,
        work.size.height,
        saved.y,
        (160. * scale) as u32,
    );
    window
        .set_position(PhysicalPosition::new(x, y))
        .map_err(|e| e.to_string())
}
fn clamp_axis(origin: i32, extent: u32, fraction: f64, window: u32) -> i32 {
    origin + (fraction * extent as f64).clamp(0., extent.saturating_sub(window) as f64) as i32
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn restores_within_changed_work_area() {
        assert_eq!(clamp_axis(-1920, 1920, 0.5, 300), -960);
        assert_eq!(clamp_axis(0, 1280, 1.2, 300), 980);
        assert_eq!(clamp_axis(20, 200, -0.5, 300), 20);
    }
}
