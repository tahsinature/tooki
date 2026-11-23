pub mod reset;
mod geometry;
mod persistence;
pub mod sizing;
mod sizing_window;
use geometry::{Axes, Point, Rect};
use serde::Serialize;
use sizing_window::remember_size;
pub use sizing_window::{applied_size, remember, requested_size};
use std::sync::Mutex;
use tauri::{Emitter, LogicalPosition, LogicalSize, Manager, WebviewWindow};

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Guides {
    left: f64,
    right: f64,
    top: f64,
    axes: Axes,
}
struct Drag {
    origin: Point,
    cursor: Point,
    axes: Axes,
    monitor: Option<(i32, i32)>,
}
#[derive(Default)]
pub struct Placement {
    drag: Mutex<Option<Drag>>,
    guides: Mutex<Option<Guides>>,
    sizing: Mutex<sizing::Sizing>,
}
fn frame(m: &tauri::Monitor) -> Rect {
    let s = m.scale_factor();
    Rect {
        x: m.position().x as f64 / s,
        y: m.position().y as f64 / s,
        width: m.size().width as f64 / s,
        height: m.size().height as f64 / s,
    }
}
fn work(m: &tauri::Monitor) -> Rect {
    let s = m.scale_factor();
    let r = m.work_area();
    Rect {
        x: r.position.x as f64 / s,
        y: r.position.y as f64 / s,
        width: r.size.width as f64 / s,
        height: r.size.height as f64 / s,
    }
}
fn require_launcher(window: &WebviewWindow) -> Result<(), String> {
    if window.label() == "main" {
        Ok(())
    } else {
        Err("Only the launcher can be repositioned by this command".into())
    }
}

#[tauri::command]
pub fn launcher_drag_start(
    x: f64,
    y: f64,
    window: WebviewWindow,
    state: tauri::State<Placement>,
) -> Result<(), String> {
    require_launcher(&window)?;
    let p = window.outer_position().map_err(|e| e.to_string())?;
    if !x.is_finite() || !y.is_finite() {
        return Err("Invalid pointer position".into());
    }
    *state.drag.lock().map_err(|e| e.to_string())? = Some(Drag {
        origin: {
            let p = p.to_logical::<f64>(window.scale_factor().map_err(|e| e.to_string())?);
            Point { x: p.x, y: p.y }
        },
        cursor: Point { x, y },
        axes: Axes::default(),
        monitor: None,
    });
    Ok(())
}
#[tauri::command]
pub fn launcher_drag_move(
    dx: f64,
    dy: f64,
    window: WebviewWindow,
    state: tauri::State<Placement>,
) -> Result<(), String> {
    require_launcher(&window)?;
    let mut guard = state.drag.lock().map_err(|e| e.to_string())?;
    let Some(drag) = guard.as_mut() else {
        return Ok(());
    };
    if !dx.is_finite() || !dy.is_finite() {
        return Err("Invalid pointer movement".into());
    }
    let cursor = Point {
        x: drag.cursor.x + dx,
        y: drag.cursor.y + dy,
    };
    let raw = Point {
        x: drag.origin.x + dx,
        y: drag.origin.y + dy,
    };
    let monitors = window.available_monitors().map_err(|e| e.to_string())?;
    // Normalize every monitor independently into desktop points before comparing.
    let monitor = monitors
        .iter()
        .find(|m| {
            let r = frame(m);
            cursor.x >= r.x
                && cursor.x < r.x + r.width
                && cursor.y >= r.y
                && cursor.y < r.y + r.height
        })
        .or_else(|| monitors.first())
        .ok_or("No display available")?;
    let scale = monitor.scale_factor();
    let width = window.inner_size().map_err(|e| e.to_string())?.width as f64
        / window.scale_factor().map_err(|e| e.to_string())?;
    let height = state
        .sizing
        .lock()
        .map_err(|e| e.to_string())?
        .preferred
        .height;
    let target = geometry::target(frame(monitor), work(monitor), width, height);
    let (position, axes) = geometry::snap(raw, target, 1.0);
    window
        .set_position(LogicalPosition::new(position.x, position.y))
        .map_err(|e| e.to_string())?;
    let monitor_key = (monitor.position().x, monitor.position().y);
    let changed = drag.monitor != Some(monitor_key) || axes != drag.axes;
    if changed {
        let guides = Guides {
            left: (target.x - monitor.position().x as f64 / scale),
            right: (target.x + width - monitor.position().x as f64 / scale),
            top: (target.y - monitor.position().y as f64 / scale),
            axes,
        };
        *state.guides.lock().map_err(|e| e.to_string())? = Some(guides.clone());
        if let Some(overlay) = window.app_handle().get_webview_window("snap-guides") {
            if drag.monitor != Some(monitor_key) {
                overlay
                    .set_size(LogicalSize::new(
                        monitor.size().width as f64 / scale,
                        monitor.size().height as f64 / scale,
                    ))
                    .map_err(|e| e.to_string())?;
                overlay
                    .set_position(LogicalPosition::new(
                        monitor.position().x as f64 / scale,
                        monitor.position().y as f64 / scale,
                    ))
                    .map_err(|e| e.to_string())?;
            }
            overlay
                .emit("launcher-guides", Some(guides))
                .map_err(|e| e.to_string())?;
            overlay.show().map_err(|e| e.to_string())?;
            overlay
                .set_ignore_cursor_events(true)
                .map_err(|e| e.to_string())?;
        }
        if (axes.x && !drag.axes.x) || (axes.y && !drag.axes.y) {
            haptic();
        }
    }
    drag.axes = axes;
    drag.monitor = Some(monitor_key);
    Ok(())
}
#[tauri::command]
pub fn launcher_drag_end(
    window: WebviewWindow,
    state: tauri::State<Placement>,
    save: bool,
) -> Result<(), String> {
    require_launcher(&window)?;
    let had_drag = state
        .drag
        .lock()
        .map_err(|e| e.to_string())?
        .take()
        .is_some();
    hide(window.app_handle());
    if save && had_drag {
        remember_size(&window)?;
        persistence::save(&window)?;
    }
    Ok(())
}
#[tauri::command]
pub fn launcher_guides(state: tauri::State<Placement>) -> Option<Guides> {
    state.guides.lock().ok()?.clone()
}
pub fn hide(app: &tauri::AppHandle) {
    if let Some(overlay) = app.get_webview_window("snap-guides") {
        let _ = overlay.hide();
        let _ = overlay.emit("launcher-guides", Option::<Guides>::None);
    }
    if let Some(state) = app.try_state::<Placement>() {
        if let Ok(mut guides) = state.guides.lock() {
            *guides = None;
        }
    }
}
pub fn restore(app: &tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        if let Err(error) = persistence::restore(&window) {
            eprintln!("Could not restore launcher position: {error}");
        }
    }
}
pub fn handle_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    if window.label() == "main"
        && matches!(
            event,
            tauri::WindowEvent::CloseRequested { .. } | tauri::WindowEvent::Focused(false)
        )
    {
        remember(window.app_handle());
    }
    if window.label() == "main"
        && matches!(
            event,
            tauri::WindowEvent::Focused(false)
                | tauri::WindowEvent::Destroyed
                | tauri::WindowEvent::CloseRequested { .. }
        )
    {
        if let Some(state) = window.app_handle().try_state::<Placement>() {
            if let Ok(mut drag) = state.drag.lock() {
                *drag = None;
            }
        }
        hide(window.app_handle());
    }
}
fn haptic() {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_alignment_haptic();
        }
        unsafe {
            tooki_alignment_haptic();
        }
    }
}
