mod commands;
mod database;
mod model;
pub(crate) mod native;
pub use commands::*;
use database::Database;
use model::{Capture, Settings};
use serde_json::json;
use std::{sync::Mutex, time::Duration};
use tauri::{Emitter, Manager};

pub struct Clipboard {
    database: Mutex<Database>,
    settings: Mutex<Settings>,
}
pub fn start(app: &tauri::AppHandle) -> Result<(), String> {
    let root = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("clipboard");
    std::fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700))
            .map_err(|e| e.to_string())?;
    }
    let settings: Settings = match std::fs::read(root.join("settings.json")) {
        Ok(bytes) => serde_json::from_slice(&bytes)
            .map_err(|e| format!("Invalid clipboard settings: {e}"))?,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Settings::default(),
        Err(e) => return Err(e.to_string()),
    };
    settings.validate()?;
    if !settings.persist_history {
        for name in [
            "history.sqlite3",
            "history.sqlite3-wal",
            "history.sqlite3-shm",
        ] {
            let _ = std::fs::remove_file(root.join(name));
        }
        let _ = std::fs::remove_dir_all(root.join("images"));
    }
    let _ = std::fs::remove_dir_all(root.join("staging"));
    let _ = std::fs::remove_dir_all(root.join("exports"));
    std::fs::create_dir_all(root.join("staging")).map_err(|e| e.to_string())?;
    let database = Database::open(&root, settings.persist_history)?;
    database.trim(&settings)?;
    app.manage(Clipboard {
        database: Mutex::new(database),
        settings: Mutex::new(settings),
    });
    let app = app.clone();
    std::thread::spawn(move || loop {
        let result = (|| -> Result<(), String> {
            let state = app.state::<Clipboard>();
            let settings = state.settings.lock().map_err(|e| e.to_string())?.clone();
            let data = native::on_main(
                &app,
                "capture",
                json!({"enabled":settings.enabled,"ignoredApps":settings.ignored_apps,"images":settings.max_images>0,"directory":root.join("staging")}),
            )?;
            if !data.is_null() {
                let capture: Capture = serde_json::from_value(data).map_err(|e| e.to_string())?;
                state
                    .database
                    .lock()
                    .map_err(|e| e.to_string())?
                    .record(capture, &settings)?;
                let _ = app.emit("clipboard-changed", ());
            }
            Ok(())
        })();
        if let Err(error) = result {
            let _ = app.emit("clipboard-error", error);
        }
        std::thread::sleep(Duration::from_millis(500));
    });
    Ok(())
}
pub fn start_ocr(app: &tauri::AppHandle) {
    let app = app.clone();
    std::thread::spawn(move || loop {
        let state = app.state::<Clipboard>();
        let enabled = state
            .settings
            .lock()
            .map(|s| s.ocr_enabled)
            .unwrap_or(false);
        let pending = if enabled {
            state.database.lock().ok().and_then(|db| {
            db.connection.query_row("SELECT id FROM clips WHERE kind='image' AND json_extract(payload,'$.ocrState')='pending' ORDER BY copied_at DESC LIMIT 1",[],|r|r.get::<_,String>(0)).ok().and_then(|id|db.get(&id).ok())
        })
        } else {
            None
        };
        if let Some(mut clip) = pending {
            let result = native::call("ocr", json!({"path":clip.image}));
            if let Ok(db) = state.database.lock() {
                if let Ok(current) = db.get(&clip.id) {
                    clip = current;
                    match result {
                        Ok(value) => {
                            clip.ocr = value.as_str().unwrap_or_default().into();
                            clip.ocr_state = "done".into();
                        }
                        Err(_) => clip.ocr_state = "failed".into(),
                    }
                    if db.update(&clip).is_ok() {
                        let _ = app.emit("clipboard-changed", ());
                    }
                }
            }
        } else {
            std::thread::sleep(Duration::from_secs(1));
        }
    });
}

#[cfg(test)]
mod tests;

pub fn cleanup(app: &tauri::AppHandle) {
    if let Some(state) = app.try_state::<Clipboard>() {
        if let (Ok(settings), Ok(db)) = (state.settings.lock(), state.database.lock()) {
            let _ = std::fs::remove_dir_all(db.root.join("exports"));
            let _ = std::fs::remove_dir_all(db.root.join("staging"));
            if !settings.persist_history {
                let _ = std::fs::remove_dir_all(db.root.join("images"));
            }
        }
    }
}
