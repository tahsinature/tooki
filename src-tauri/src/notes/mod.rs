mod search;
mod storage;
#[cfg(test)]
mod tests;
mod window;

use serde_json::{json, Value};
use std::sync::Mutex;
use storage::{empty_document, Storage};
use tauri::{AppHandle, Emitter, Manager, WebviewWindow};
use tauri_plugin_deep_link::DeepLinkExt;
use tauri_plugin_dialog::DialogExt;

#[derive(serde::Serialize)]
pub struct OpenRequest {
    id: String,
    created: bool,
}

pub struct Notes(
    pub Mutex<Storage>,
    pub Mutex<Option<OpenRequest>>,
    pub Mutex<bool>,
);
pub fn initialize(app: &AppHandle) -> Result<(), String> {
    let root = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("notes");
    std::fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    app.manage(Notes(
        Mutex::new(Storage::open(&root.join("notes.sqlite3"))?),
        Mutex::new(None),
        Mutex::new(false),
    ));
    let handle = app.clone();
    let route = move |url: tauri::Url| {
        if url.host_str() != Some("notes") {
            return;
        }
        let id = parse_link(&url);
        let app = handle.clone();
        tauri::async_runtime::spawn(async move {
            let result = match id {
                Ok(id) => open_notes(app.clone(), Some(id), false).await,
                Err(e) => Err(e),
            };
            if let Err(e) = result {
                app.dialog().message(e).title("Notes link").show(|_| {});
            }
        });
    };
    let startup = app
        .deep_link()
        .get_current()
        .ok()
        .flatten()
        .unwrap_or_default();
    for url in startup {
        route(url);
    }
    app.deep_link().on_open_url(move |event| {
        for url in event.urls() {
            route(url);
        }
    });
    Ok(())
}
fn parse_link(url: &tauri::Url) -> Result<String, String> {
    let id = url.path().trim_start_matches('/');
    if !["tooki", "tooki-preview", "tooki-dev"].contains(&url.scheme())
        || url.host_str() != Some("notes")
        || !url.username().is_empty()
        || url.password().is_some()
        || url.port().is_some()
        || url.query().is_some()
        || url.fragment().is_some()
        || id.len() != 32
        || !id.bytes().all(|b| b.is_ascii_hexdigit())
    {
        return Err("Invalid Notes link.".into());
    }
    Ok(id.into())
}
#[tauri::command]
pub async fn open_notes(app: AppHandle, id: Option<String>, create: bool) -> Result<(), String> {
    let requested = {
        let state = app.state::<Notes>();
        let db = state.0.lock().map_err(|e| e.to_string())?;
        if create {
            Some(db.create(&default_note_title(), empty_document())?.id)
        } else if let Some(id) = id {
            let note = db.get(&id)?;
            if note.deleted {
                return Err("This note is in Trash. Restore it from Browse Notes.".into());
            }
            Some(id)
        } else {
            None
        }
    };
    if let Some(id) = requested {
        *app.state::<Notes>().1.lock().map_err(|e| e.to_string())? = Some(OpenRequest { id, created: create });
    }
    window::show(&app)?;
    if let Some(notes) = app.get_webview_window("notes") {
        let _ = notes.emit("notes-open", ());
    }
    Ok(())
}
#[tauri::command]
pub async fn notes_request(
    app: AppHandle,
    window: WebviewWindow,
    action: String,
    args: Value,
) -> Result<Value, String> {
    if !matches!(window.label(), "notes" | "main") {
        return Err("Notes are unavailable in this window.".into());
    }
    if window.label() == "main" && action != "search" {
        return Err("Open Notes to edit notes.".into());
    }
    if action == "hide" {
        window::remember(&app);
        crate::windows::dismiss(&window, crate::windows::Role::Workspace).map_err(|e| e.to_string())?;
        return Ok(Value::Null);
    }
    if action == "takeBrowseRequest" {
        return Ok(json!(std::mem::take(
            &mut *app.state::<Notes>().2.lock().map_err(|e| e.to_string())?
        )));
    }
    if action == "takeRequest" {
        return Ok(json!(app
            .state::<Notes>()
            .1
            .lock()
            .map_err(|e| e.to_string())?
            .take()));
    }
    if action == "export" {
        if window.label() != "notes" {
            return Err("Open Notes to export.".into());
        }
        let format = args["format"].as_str().unwrap_or("txt");
        if !matches!(format, "txt" | "html" | "json") {
            return Err("Unknown export format".into());
        }
        let contents = args["contents"]
            .as_str()
            .ok_or("Missing export content")?
            .to_owned();
        if contents.len() > 4_000_000 {
            return Err("Export is too large.".into());
        }
        let format = format.to_owned();
        return tauri::async_runtime::spawn_blocking(move || {
            let path = app
                .dialog()
                .file()
                .set_parent(&window)
                .set_title("Export note")
                .set_file_name(format!("note.{format}"))
                .add_filter("Note", &[format.as_str()])
                .blocking_save_file();
            if let Some(path) = path {
                std::fs::write(path.into_path().map_err(|e| e.to_string())?, contents)
                    .map_err(|e| e.to_string())?;
                return Ok(json!(true));
            }
            Ok(json!(false))
        })
        .await
        .map_err(|e| e.to_string())?;
    }
    let handle = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let state = handle.state::<Notes>();
        let db = state.0.lock().map_err(|e| e.to_string())?;
        let id = args["id"].as_str().unwrap_or_default();
        if window.label() == "main" && action != "search" {
            return Err("Open Notes to edit notes.".into());
        }
        let result = match action.as_str() {
            "search" => json!(db.search(
                args["query"].as_str().unwrap_or_default(),
                args["deleted"].as_bool().unwrap_or(false)
            )?),
            "get" => {
                let note = db.get(id)?;
                db.set_state("lastNote", id)?;
                json!(note)
            }
            "lastNote" => json!(db.state("lastNote")),
            "create" => json!(db.create(
                args["title"].as_str().unwrap_or(&default_note_title()),
                args.get("document").cloned().unwrap_or_else(empty_document)
            )?),
            "save" => json!(db.save(
                id,
                args["revision"].as_i64().ok_or("Missing revision")?,
                args["title"].as_str().unwrap_or_default(),
                args["document"].clone()
            )?),
            "pin" => json!(db.flag(
                id,
                "pinned",
                args["value"].as_bool().ok_or("Missing value")?
            )?),
            "trash" => json!(db.flag(id, "deleted", true)?),
            "restore" => json!(db.flag(id, "deleted", false)?),
            _ => return Err("Unknown Notes action".into()),
        };
        if matches!(
            action.as_str(),
            "save" | "create" | "pin" | "trash" | "restore"
        ) {
            let _ = handle.emit("notes-changed", ());
        }
        if action == "trash" {
            crate::platform::toast::show_for_window(&handle, "notes", "Note moved to Trash", false);
        }
        Ok(result)
    })
    .await
    .map_err(|e| e.to_string())?
}
pub use window::{handle_event, remember};

fn default_note_title() -> String {
    chrono::Local::now().format("%Y-%m-%d_%H:%M:%S__note").to_string()
}
