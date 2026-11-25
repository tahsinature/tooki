use super::{
    drop_storage::{DropContent, PreparedDrop},
    Clipboard,
};
use std::sync::atomic::Ordering;
use tauri::{Emitter, Manager};

pub fn handle_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    if window.label() != "main" {
        return;
    }
    let tauri::WindowEvent::DragDrop(event) = event else {
        return;
    };
    let app = window.app_handle();
    if crate::launcher_presentation::active_view(app) != "clipboard" {
        return;
    }
    let Some(state) = app.try_state::<Clipboard>() else {
        return;
    };
    if state.importing.load(Ordering::Acquire) {
        if matches!(event, tauri::DragDropEvent::Drop { .. }) {
            let _ = window.emit_to(
                "main",
                "clipboard-error",
                "Still adding the previous drop. Please drop this item again when it finishes.",
            );
        }
        return;
    }
    match event {
        tauri::DragDropEvent::Enter { .. } | tauri::DragDropEvent::Over { .. } => {
            let _ = window.emit_to("main", "clipboard-drop-state", "hover");
        }
        tauri::DragDropEvent::Drop { paths, .. } => {
            // Snapshot within the native callback, before the drag pasteboard expires.
            #[cfg(target_os = "macos")]
            let content = crate::platform::shelf::content::drag_snapshot().and_then(|value| {
                serde_json::from_value::<DropContent>(value).map_err(|e| e.to_string())
            });
            #[cfg(not(target_os = "macos"))]
            let content: Result<DropContent, String> = Ok(DropContent::default());
            let paths = paths.clone();
            state.importing.store(true, Ordering::Release);
            let _ = window.emit_to("main", "clipboard-drop-state", "saving");
            let app = app.clone();
            tauri::async_runtime::spawn_blocking(move || {
                let state = app.state::<Clipboard>();
                let result = (|| {
                    let mut content = content?;
                    if !paths.is_empty() {
                        content.files = paths
                            .iter()
                            .map(|p| p.to_string_lossy().into_owned())
                            .collect();
                    }
                    let root = state
                        .database
                        .lock()
                        .map_err(|e| e.to_string())?
                        .root
                        .clone();
                    let prepared = PreparedDrop::prepare(&root, content)?;
                    let settings = state.settings.lock().map_err(|e| e.to_string())?.clone();
                    let db = state.database.lock().map_err(|e| e.to_string())?;
                    prepared.record(&db, &settings)
                })();
                state.importing.store(false, Ordering::Release);
                let _ = app.emit_to("main", "clipboard-drop-state", "");
                match result {
                    Ok(id) => {
                        let _ = app.emit_to("main", "clipboard-dropped", id);
                    }
                    Err(error) => {
                        let _ = app.emit_to("main", "clipboard-error", error);
                    }
                }
            });
        }
        _ => {
            let _ = window.emit_to("main", "clipboard-drop-state", "");
        }
    }
}
