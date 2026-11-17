//! Copy large files off the shared library lock, then merge against its latest state.
use super::{model::*, request, required, storage::Storage, Shelves};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use tauri::{Emitter, Manager};
fn duplicate(a: &Item, b: &Item) -> bool {
    a.owned == b.owned
        && if a.owned {
            a.original_path == b.original_path
        } else {
            a.path == b.path
        }
}
pub fn add_files(app: &tauri::AppHandle, args: Value) -> Result<Value, String> {
    request(app, "list", json!({}))?;
    let id = required(&args, "shelf")?.to_owned();
    let copy = args["copy"].as_bool().unwrap_or(false);
    let paths = args["paths"]
        .as_array()
        .ok_or("Choose files to add")?
        .iter()
        .map(|p| {
            PathBuf::from(p.as_str().ok_or("Invalid path")?)
                .canonicalize()
                .map_err(|e| e.to_string())
        })
        .collect::<Result<Vec<_>, String>>()?;
    let state = app.state::<Shelves>();
    let (root, existing) = {
        let guard = state.0.lock().map_err(|e| e.to_string())?;
        let store = guard.as_ref().ok_or("Shelf unavailable")?;
        if !store.library.settings.enabled {
            return Err("Shelf is disabled".into());
        }
        let shelf = store
            .library
            .shelves
            .iter()
            .find(|s| s.id == id)
            .ok_or("Shelf not found")?;
        (store.root.clone(), shelf.items.clone())
    };
    let files = Storage {
        root,
        library: Library::default(),
    };
    let mut prepared: Vec<Item> = vec![];
    let result = (|| {
        for (index, path) in paths.iter().enumerate() {
            if existing.iter().chain(prepared.iter()).any(|item| {
                item.owned == copy
                    && Path::new(if copy {
                        item.original_path.as_deref().unwrap_or(&item.path)
                    } else {
                        &item.path
                    }) == path
            }) {
                continue;
            }
            let _ = app.emit_to(
                format!("shelf-{id}"),
                "shelf-import-progress",
                json!({"done":index,"total":paths.len()}),
            );
            prepared.push(files.file(path, copy)?);
        }
        let mut guard = state.0.lock().map_err(|e| e.to_string())?;
        let store = guard.as_mut().ok_or("Shelf unavailable")?;
        if !store.library.settings.enabled {
            return Err("Shelf was disabled while copying".into());
        }
        let mut next = store.library.clone();
        let shelf = next
            .shelves
            .iter_mut()
            .find(|s| s.id == id)
            .ok_or("Shelf was removed while copying")?;
        let mut duplicates = vec![];
        for item in &prepared {
            if shelf.items.iter().any(|current| duplicate(current, item)) {
                duplicates.push(item.clone());
            } else {
                shelf.items.push(item.clone());
            }
        }
        store.save(next)?;
        for item in duplicates {
            store.remove_owned(&item);
        }
        Ok(Value::Null)
    })();
    if result.is_err() {
        for item in &prepared {
            files.remove_owned(item);
        }
    }
    let _ = app.emit_to(format!("shelf-{id}"), "shelf-import-progress", Value::Null);
    if result.is_ok() {
        let _ = app.emit("shelf-changed", ());
    }
    result
}
