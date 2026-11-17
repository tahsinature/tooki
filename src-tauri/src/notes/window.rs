use super::Notes;
use serde::{Deserialize, Serialize};
use tauri::{Emitter, LogicalSize, Manager, PhysicalPosition};

#[derive(Serialize, Deserialize)]
struct Geometry {
    x: i32,
    y: i32,
    width: f64,
    height: f64,
}
pub fn show(app: &tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("notes") {
        window.unminimize().map_err(|e| e.to_string())?;
        window.show().map_err(|e| e.to_string())?;
        return window.set_focus().map_err(|e| e.to_string());
    }
    let builder = tauri::WebviewWindowBuilder::new(
        app,
        "notes",
        tauri::WebviewUrl::App("index.html?window=notes".into()),
    )
    .title("Tooki Notes")
    .accept_first_mouse(true)
    .inner_size(460., 600.)
    .min_inner_size(380., 360.)
    .resizable(true)
    .decorations(false)
    .transparent(true)
    .visible(false)
    .on_navigation(|url| {
        matches!(url.scheme(), "tauri" | "http" | "https")
            && matches!(
                url.host_str(),
                Some("localhost" | "tauri.localhost" | "127.0.0.1")
            )
    });
    let window = builder.build().map_err(|e| e.to_string())?;
    crate::platform::window_chrome::apply(&window)?;
    let saved = app
        .state::<Notes>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .state("window")
        .and_then(|s| serde_json::from_str::<Geometry>(&s).ok());
    if let Some(saved) = saved.filter(|g| g.width.is_finite() && g.height.is_finite()) {
        let monitor = window
            .monitor_from_point(saved.x as f64, saved.y as f64)
            .ok()
            .flatten()
            .or(window.primary_monitor().ok().flatten());
        if let Some(m) = monitor {
            let work = m.work_area();
            let scale = m.scale_factor();
            let width = saved
                .width
                .clamp(380., (work.size.width as f64 / scale).max(380.));
            let height = saved
                .height
                .clamp(360., (work.size.height as f64 / scale).max(360.));
            window
                .set_size(LogicalSize::new(width, height))
                .map_err(|e| e.to_string())?;
            let x = saved.x.clamp(
                work.position.x,
                (work.position.x + work.size.width as i32 - (width * scale) as i32)
                    .max(work.position.x),
            );
            let y = saved.y.clamp(
                work.position.y,
                (work.position.y + work.size.height as i32 - (height * scale) as i32)
                    .max(work.position.y),
            );
            window
                .set_position(PhysicalPosition::new(x, y))
                .map_err(|e| e.to_string())?;
        }
    } else {
        window.center().map_err(|e| e.to_string())?;
    }
    window.show().map_err(|e| e.to_string())?;
    window.set_focus().map_err(|e| e.to_string())
}
pub fn remember(app: &tauri::AppHandle) {
    let Some(w) = app.get_webview_window("notes") else {
        return;
    };
    if w.is_minimized().unwrap_or(false) || w.is_maximized().unwrap_or(false) {
        return;
    }
    if let (Ok(pos), Ok(size), Ok(scale)) = (w.outer_position(), w.inner_size(), w.scale_factor()) {
        let g = Geometry {
            x: pos.x,
            y: pos.y,
            width: size.width as f64 / scale,
            height: size.height as f64 / scale,
        };
        if let Ok(db) = app.state::<Notes>().0.lock() {
            let _ = db.set_state("window", &serde_json::to_string(&g).unwrap_or_default());
        }
    }
}
pub fn handle_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    if window.label() != "notes" {
        return;
    }
    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
        api.prevent_close();
        let _ = window.emit("notes-close", ());
    }
}
