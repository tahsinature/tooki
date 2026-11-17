use super::{drag_session, request};
use serde_json::{json, Value};
use std::sync::{mpsc, OnceLock};
use tauri::{Emitter, Manager};
enum WatcherEvent {
    Native(u8),
    Cleanup(u64),
}
static EVENTS: OnceLock<mpsc::Sender<WatcherEvent>> = OnceLock::new();
pub(super) fn schedule_cleanup(generation: u64) {
    tauri::async_runtime::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_millis(400)).await;
        if let Some(tx) = EVENTS.get() {
            let _ = tx.send(WatcherEvent::Cleanup(generation));
        }
    });
}
pub fn available() -> bool {
    crate::platform::shelf::available()
}
pub fn capabilities() -> Value {
    json!({"shiftDrag":available(), "shiftDragReason": if available() { "" } else {
        "This desktop does not yet have a global content-drag adapter. Open a shelf manually, then drop files onto it."
    }})
}
extern "C" fn event(kind: u8) {
    if let Some(tx) = EVENTS.get() {
        let _ = tx.send(WatcherEvent::Native(kind));
    }
}
pub fn configure(app: &tauri::AppHandle, enabled: bool) -> Result<(), String> {
    EVENTS.get_or_init(|| {
        let (tx, rx) = mpsc::channel();
        let app = app.clone();
        std::thread::spawn(move || {
            for event in rx {
                let kind = match event {
                    WatcherEvent::Native(kind) => kind,
                    WatcherEvent::Cleanup(generation) => {
                        drag_session::finish(&app, generation);
                        continue;
                    }
                };
                if kind == 3 || kind == 4 {
                    let _ = app.emit("shelf-modifiers", json!({"option":kind==3}));
                } else if kind == 1 {
                    if let Err(e) = drag_session::show(&app) {
                        eprintln!("Shelf Shift-drag: {e}");
                    }
                } else if kind == 2 {
                    drag_session::end();
                }
            }
        });
        tx
    });
    crate::platform::shelf::configure(app, enabled, event)
}
pub fn handle_window_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    let Some(id) = window.label().strip_prefix("shelf-") else {
        return;
    };
    let tauri::WindowEvent::DragDrop(event) = event else {
        return;
    };
    let position = match event {
        tauri::DragDropEvent::Enter { position, .. }
        | tauri::DragDropEvent::Over { position }
        | tauri::DragDropEvent::Drop { position, .. } => Some(position),
        _ => None,
    };
    let copy = position.is_some_and(|p| {
        let Ok(size) = window.inner_size() else {
            return false;
        };
        // Wry 0.57's WKWebView drag callback reports AppKit points, despite Tauri's
        // PhysicalPosition wrapper. Reassess this conversion when upgrading Wry.
        #[cfg(target_os = "macos")]
        let width = size.width as f64 / window.scale_factor().unwrap_or(1.);
        #[cfg(not(target_os = "macos"))]
        let width = size.width as f64;
        p.x >= width / 2.
    });
    #[cfg(target_os = "macos")]
    let content_drop = !crate::platform::shelf::content::drag_has_files();
    #[cfg(not(target_os = "macos"))]
    let content_drop = false;
    let state = match event {
        tauri::DragDropEvent::Enter { .. } | tauri::DragDropEvent::Over { .. } => {
            if content_drop {
                "content"
            } else if copy {
                "copy"
            } else {
                "original"
            }
        }
        _ => "",
    };
    // Drag feedback belongs only to this shelf; emit() broadcasts to every window.
    let _ = window.emit_to(window.label(), "shelf-drop-state", state);
    let tauri::DragDropEvent::Drop { paths, .. } = event else {
        return;
    };
    drag_session::received_drop(id);
    let app = window.app_handle().clone();
    let id = id.to_owned();
    let paths = paths.clone();
    #[cfg(target_os = "macos")]
    let content = crate::platform::shelf::content::drag_snapshot();
    #[cfg(not(target_os = "macos"))]
    let content: Result<Value, String> = Ok(Value::Null);
    tauri::async_runtime::spawn_blocking(move || {
        let result = if !paths.is_empty() {
            request(
                &app,
                "addFiles",
                json!({"shelf":id,"paths":paths,"copy":copy}),
            )
        } else {
            content.and_then(|content| {
                request(&app, "addContent", json!({"shelf":id,"content":content}))
            })
        };
        if let Err(e) = result {
            let _ = app.emit_to(format!("shelf-{id}"), "shelf-error", e);
        }
    });
}
pub fn stop() {
    crate::platform::shelf::stop();
}

pub use super::drag_session::is_temporary;
