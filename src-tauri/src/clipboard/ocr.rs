use super::{database::Database, native, Clipboard};
use serde_json::json;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, Manager};

pub(super) fn run(app: &AppHandle, id: &str, force: bool) -> Result<String, String> {
    let state = app.state::<Clipboard>();
    // Automatic and requested recognition share one worker at a time.
    let _recognition = state.recognition.lock().map_err(|e| e.to_string())?;
    let mut attempted = false;
    let result = recognize(&state.database, id, force, |path| {
        attempted = true;
        native::call("ocr", json!({"path": path}))?
            .as_str()
            .map(str::to_owned)
            .ok_or_else(|| "Text recognition returned an invalid result.".into())
    });
    if attempted {
        let _ = app.emit("clipboard-changed", ());
    }
    result
}

pub(super) fn recognize(
    database: &Mutex<Database>,
    id: &str,
    force: bool,
    recognize_image: impl FnOnce(&str) -> Result<String, String>,
) -> Result<String, String> {
    let clip = database.lock().map_err(|e| e.to_string())?.get(id)?;
    if clip.kind != "image" || clip.image.is_empty() {
        return Err("Choose an image to recognize text.".into());
    }
    if !force && clip.ocr_state == "done" {
        return Ok(clip.ocr);
    }
    // Vision can take time. Leave the database available for browsing and capture.
    let result = recognize_image(&clip.image);
    let db = database.lock().map_err(|e| e.to_string())?;
    // Read again to preserve concurrent pin/copy changes and never resurrect a deleted clip.
    let mut current = db.get(id)?;
    match &result {
        Ok(text) => {
            current.ocr = text.clone();
            current.ocr_state = "done".into();
        }
        Err(_) => current.ocr_state = "failed".into(),
    }
    db.update(&current)?;
    result
}
