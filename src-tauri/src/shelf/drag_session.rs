use super::{request, window};
use serde_json::json;
use std::sync::Mutex;
use tauri::{Emitter, Manager, PhysicalPosition};

#[derive(Default)]
struct DragSession {
    generation: u64,
    shelves: Vec<RevealedShelf>,
}
struct RevealedShelf {
    id: String,
    was_visible: bool,
    was_minimized: bool,
    was_on_top: bool,
    created: bool,
    received_drop: bool,
}
impl DragSession {
    fn finish(&mut self, generation: u64) -> Vec<RevealedShelf> {
        if self.generation != generation {
            return Vec::new();
        }
        std::mem::take(&mut self.shelves)
    }
}
impl RevealedShelf {
    fn hide_after_drag(&self) -> bool {
        !self.created && (!self.was_visible || self.was_minimized)
    }
    fn discard_after_drag(&self) -> bool {
        self.created && !self.received_drop
    }
}
static SESSION: Mutex<DragSession> = Mutex::new(DragSession {
    generation: 0,
    shelves: Vec::new(),
});

pub fn show(app: &tauri::AppHandle) -> Result<(), String> {
    {
        let mut session = SESSION.lock().map_err(|e| e.to_string())?;
        // A new drag during the cleanup grace period reuses the original visibility snapshot.
        session.generation += 1;
        if !session.shelves.is_empty() {
            return Ok(());
        }
    }
    let library = request(app, "list", json!({}))?;
    if library["settings"]["showOnShiftDrag"] != true || library["settings"]["enabled"] != true {
        return Ok(());
    }
    let mut shelves: Vec<(String, String)> = library["shelves"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|s| {
            Some((
                s["id"].as_str()?.into(),
                s["name"].as_str().unwrap_or("Shelf").into(),
            ))
        })
        .collect();
    let created = shelves.is_empty();
    if created {
        let id = request(app, "create", json!({"name":"Shelf"}))?
            .as_str()
            .ok_or("Missing Shelf id")?
            .to_owned();
        shelves.push((id, "Shelf".into()));
    }
    for (id, title) in shelves {
        let existing = app.get_webview_window(&format!("shelf-{id}"));
        let snapshot = RevealedShelf {
            id: id.clone(),
            was_visible: existing
                .as_ref()
                .is_some_and(|w| w.is_visible().unwrap_or(false)),
            was_minimized: existing
                .as_ref()
                .is_some_and(|w| w.is_minimized().unwrap_or(false)),
            was_on_top: existing
                .as_ref()
                .is_some_and(|w| w.is_always_on_top().unwrap_or(false)),
            created,
            received_drop: false,
        };
        SESSION
            .lock()
            .map_err(|e| e.to_string())?
            .shelves
            .push(snapshot);
        // Register before showing so the frontend's keep-on-top preference cannot undo drag visibility.
        window::show_with_focus(app, &id, &title, false)?;
        if let Some(w) = app.get_webview_window(&format!("shelf-{id}")) {
            w.unminimize().map_err(|e| e.to_string())?;
            w.set_always_on_top(true).map_err(|e| e.to_string())?;
        }
        if created {
            position_temporary(app, &id)?;
        }
    }
    Ok(())
}

fn position_temporary(app: &tauri::AppHandle, id: &str) -> Result<(), String> {
    if let (Some(window), Ok(cursor)) = (
        app.get_webview_window(&format!("shelf-{id}")),
        app.cursor_position(),
    ) {
        if let Ok(Some(m)) = app.monitor_from_point(cursor.x, cursor.y) {
            let work = m.work_area();
            let scale = m.scale_factor();
            let right = cursor.x + 60. * scale;
            let proposed_x =
                if right + 300. * scale > work.position.x as f64 + work.size.width as f64 {
                    cursor.x - 360. * scale
                } else {
                    right
                };
            let x = proposed_x.clamp(
                work.position.x as f64,
                (work.position.x as f64 + work.size.width as f64 - 300. * scale)
                    .max(work.position.x as f64),
            );
            let y = (cursor.y - 80. * scale).clamp(
                work.position.y as f64,
                (work.position.y as f64 + work.size.height as f64 - 160. * scale)
                    .max(work.position.y as f64),
            );
            window
                .set_position(PhysicalPosition::new(x as i32, y as i32))
                .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

// Every shelf revealed for a drag is temporarily raised, including existing shelves.
pub fn is_temporary(label: &str) -> bool {
    SESSION
        .lock()
        .ok()
        .is_some_and(|s| s.shelves.iter().any(|s| label == format!("shelf-{}", s.id)))
}
pub fn received_drop(id: &str) {
    if let Ok(mut session) = SESSION.lock() {
        if let Some(shelf) = session.shelves.iter_mut().find(|s| s.id == id) {
            shelf.received_drop = true;
        }
    }
}
pub fn end() {
    let generation = SESSION.lock().map(|s| s.generation).unwrap_or_default();
    // Allow the native drop callback to mark asynchronous imports before cleanup.
    super::drag_watcher::schedule_cleanup(generation);
}
// Cleanup and revealing run on the same worker, so a new drag cannot snapshot half-restored windows.
pub fn finish(app: &tauri::AppHandle, generation: u64) {
    let shelves = {
        let Ok(mut session) = SESSION.lock() else {
            return;
        };
        session.finish(generation)
    };
    for shelf in shelves {
        if let Some(w) = app.get_webview_window(&format!("shelf-{}", shelf.id)) {
            let _ = w.emit_to(w.label(), "shelf-drop-state", "");
            let _ = w.set_always_on_top(shelf.was_on_top);
            if shelf.was_minimized {
                let _ = w.minimize();
            } else if shelf.hide_after_drag() {
                let _ = w.hide();
            }
        }
        if shelf.discard_after_drag() {
            let app = app.clone();
            tauri::async_runtime::spawn_blocking(move || {
                let _ = request(&app, "discardEmpty", json!({"shelf":shelf.id}));
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn shelf(visible: bool, created: bool, received_drop: bool) -> RevealedShelf {
        RevealedShelf {
            id: "test".into(),
            was_visible: visible,
            was_minimized: false,
            was_on_top: true,
            created,
            received_drop,
        }
    }
    #[test]
    fn existing_shelves_restore_visibility_and_are_never_discarded() {
        for received_drop in [false, true] {
            let hidden = shelf(false, false, received_drop);
            assert!(hidden.hide_after_drag());
            assert!(!hidden.discard_after_drag());
            let mut visible = shelf(true, false, received_drop);
            assert!(!visible.hide_after_drag());
            assert!(!visible.discard_after_drag());
            visible.was_minimized = true;
            assert!(visible.hide_after_drag());
        }
    }
    #[test]
    fn temporary_shelf_survives_an_asynchronous_drop() {
        assert!(shelf(false, true, false).discard_after_drag());
        let dropped = shelf(false, true, true);
        assert!(!dropped.discard_after_drag());
        assert!(!dropped.hide_after_drag());
    }
    #[test]
    fn old_cleanup_cannot_take_a_new_drag_session() {
        let mut session = DragSession {
            generation: 2,
            shelves: vec![shelf(false, false, false)],
        };
        assert!(session.finish(1).is_empty());
        assert_eq!(session.shelves.len(), 1);
        let restored = session.finish(2);
        assert_eq!(restored.len(), 1);
        assert!(restored[0].was_on_top);
        assert!(session.finish(2).is_empty());
    }
}
