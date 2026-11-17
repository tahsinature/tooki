use super::{
    model::{Clip, Settings},
    native, Clipboard,
};
use base64::Engine;
use serde_json::{json, Value};
use tauri::{AppHandle, Emitter, Manager};

// Commands run on the blocking pool: SQLite and native main-thread requests never block the webview.
#[tauri::command]
pub async fn clipboard_request(
    app: AppHandle,
    window: tauri::WebviewWindow,
    operation: String,
    mut args: Value,
) -> Result<Value, String> {
    args["previewOwner"] = json!(window.label());
    tauri::async_runtime::spawn_blocking(move || request(&app, &operation, args))
        .await
        .map_err(|e| e.to_string())?
}
fn item(app: &AppHandle, args: &Value) -> Result<Clip, String> {
    let state = app.state::<Clipboard>();
    let db = state.database.lock().map_err(|e| e.to_string())?;
    db.get(args["id"].as_str().ok_or("Missing clipboard item")?)
}
fn paths(app: &AppHandle, clip: &Clip) -> Result<Vec<String>, String> {
    let paths = if !clip.files.is_empty() {
        clip.files.clone()
    } else if !clip.image.is_empty() {
        vec![clip.image.clone()]
    } else {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|e| e.to_string())?
            .join("clipboard/exports");
        std::fs::create_dir_all(&root).map_err(|e| e.to_string())?;
        let path = root.join(format!("{}.txt", clip.id));
        std::fs::write(&path, &clip.content).map_err(|e| e.to_string())?;
        vec![path.to_string_lossy().into()]
    };
    if paths.iter().any(|p| !std::path::Path::new(p).exists()) {
        return Err("An original file has moved or been deleted.".into());
    }
    Ok(paths)
}
fn request(app: &AppHandle, operation: &str, args: Value) -> Result<Value, String> {
    let state = app.state::<Clipboard>();
    match operation {
        "search" => {
            let db = state.database.lock().map_err(|e| e.to_string())?;
            let query = args["query"].as_str().unwrap_or("");
            let kind = args["kind"].as_str().unwrap_or("all");
            let anchor = match args["anchor"].as_str() {
                Some(id) => db.locate(query, kind, id)?,
                None => None,
            };
            let offset = anchor
                .map(|index| index / 100 * 100)
                .unwrap_or(args["offset"].as_u64().unwrap_or(0) as usize);
            let (mut items, total) = db.search(
                args["query"].as_str().unwrap_or(""),
                args["kind"].as_str().unwrap_or("all"),
                offset,
                100,
            )?;
            for clip in &mut items {
                clip.content = clip.content.chars().take(200).collect();
                clip.ocr.clear();
            }
            Ok(json!({"items":items,"total":total,"offset":offset,"selected":anchor}))
        }
        "addToShelf" => Err(crate::shelf::LEGACY_NOTICE.into()),
        "detail" => {
            let mut clip = item(app, &args)?;
            clip.missing_files = clip
                .files
                .iter()
                .filter(|p| !std::path::Path::new(p).exists())
                .cloned()
                .collect();
            Ok(json!(clip))
        }
        "settings" => Ok(json!(*state.settings.lock().map_err(|e| e.to_string())?)),
        "saveSettings" => {
            let next: Settings = serde_json::from_value(args).map_err(|e| e.to_string())?;
            next.validate()?;
            let mut settings = state.settings.lock().map_err(|e| e.to_string())?;
            let mut db = state.database.lock().map_err(|e| e.to_string())?;
            if next.persist_history != settings.persist_history {
                db.set_persistence(next.persist_history)?;
            }
            if let Err(error) = super::preferences::save(app, &next) {
                if next.persist_history != settings.persist_history {
                    db.set_persistence(settings.persist_history)?;
                }
                return Err(error.to_string());
            }
            *settings = next.clone();
            db.trim(&next)?;
            if next.ocr_enabled {
                let ids = {
                    let mut q=db.connection.prepare("SELECT id FROM clips WHERE kind='image' AND json_extract(payload,'$.ocrState')='none'").map_err(|e|e.to_string())?;
                    let rows = q
                        .query_map([], |r| r.get::<_, String>(0))
                        .map_err(|e| e.to_string())?;
                    rows.collect::<Result<Vec<_>, _>>()
                        .map_err(|e| e.to_string())?
                };
                for id in ids {
                    let mut clip = db.get(&id)?;
                    clip.ocr_state = "pending".into();
                    db.update(&clip)?;
                }
            }
            let _ = app.emit("clipboard-changed", ());
            Ok(json!(next))
        }
        "pin" | "delete" | "retryOcr" => {
            let settings = state.settings.lock().map_err(|e| e.to_string())?.clone();
            let db = state.database.lock().map_err(|e| e.to_string())?;
            let mut clip = db.get(args["id"].as_str().ok_or("Missing clipboard item")?)?;
            if operation == "delete" {
                db.remove(&clip.id)?;
            } else {
                if operation == "pin" {
                    clip.pinned = !clip.pinned;
                } else {
                    clip.ocr_state = "pending".into();
                }
                db.update(&clip)?;
                if operation == "pin" {
                    db.trim(&settings)?;
                }
            }
            let _ = app.emit("clipboard-changed", ());
            Ok(Value::Null)
        }
        "clear" => {
            state
                .database
                .lock()
                .map_err(|e| e.to_string())?
                .clear(args["includePinned"].as_bool().unwrap_or(false))?;
            let _ = app.emit("clipboard-changed", ());
            Ok(Value::Null)
        }
        "image" => {
            let clip = item(app, &args)?;
            if clip.image.is_empty() {
                return Ok(Value::Null);
            }
            let bytes = std::fs::read(clip.image).map_err(|e| e.to_string())?;
            Ok(json!(format!(
                "data:image/png;base64,{}",
                base64::engine::general_purpose::STANDARD.encode(bytes)
            )))
        }
        "copy" | "paste" => {
            let clip = item(app, &args)?;
            if !clip.files.is_empty() || !clip.image.is_empty() {
                paths(app, &clip)?;
            }
            native::on_main(
                app,
                "copy",
                json!({"item":clip,"mode":args["mode"].as_str().unwrap_or("original")}),
            )?;
            if operation == "paste" {
                native::on_main(app, "paste", json!({}))?;
            }
            crate::launcher_presentation::dismiss_launcher(app.clone())?;
            Ok(Value::Null)
        }
        "preview" | "previewUpdate" | "open" | "apps" | "drag" => {
            let owner = args["previewOwner"].as_str().unwrap_or("main");
            if operation == "previewUpdate"
                && !crate::platform::preview::active(app, owner, "clipboard")?
            {
                return Ok(Value::Null);
            }
            let mut clip = item(app, &args)?;
            if matches!(operation, "preview" | "previewUpdate")
                && args["mode"].as_str() == Some("ocr")
            {
                if clip.kind != "image" || clip.ocr_state != "done" {
                    return Err(
                        "Recognized text is not ready. Retry recognition from Actions.".into(),
                    );
                }
                // A temporary text representation, never written back to history.
                clip.id = format!("{}-recognized-text", clip.id);
                clip.content = if clip.ocr.trim().is_empty() {
                    "No text was recognized in this image.".into()
                } else {
                    clip.ocr.clone()
                };
                clip.kind = "text".into();
                clip.image.clear();
                clip.files.clear();
            }
            if operation == "drag" {
                return Ok(
                    json!({"paths":paths(app, &clip)?,"icon":format!("data:image/png;base64,{}",base64::engine::general_purpose::STANDARD.encode(include_bytes!("../../icons/icon.png")))}),
                );
            }
            let files = paths(app, &clip)?;
            if matches!(operation, "preview" | "previewUpdate") {
                return crate::platform::preview::show(
                    app,
                    owner,
                    "clipboard",
                    json!(files),
                    operation == "previewUpdate",
                );
            }
            let mut payload = json!({"paths":files,"path":files[0]});
            if clip.kind == "link" && operation != "preview" {
                payload["url"] = json!(clip.content);
                payload["paths"] = json!([]);
            }
            if let Some(path) = args["app"].as_str() {
                let apps = native::on_main(app, "apps", payload.clone())?;
                if !apps.as_array().is_some_and(|list| {
                    list.iter()
                        .any(|entry| entry["path"].as_str() == Some(path))
                }) {
                    return Err("Choose an application from Open With.".into());
                }
                payload["app"] = json!(path);
            }
            native::on_main(app, operation, payload)
        }
        _ => Err("Unknown clipboard operation".into()),
    }
}
