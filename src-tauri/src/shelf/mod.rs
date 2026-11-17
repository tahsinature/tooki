mod actions;
mod conversion;
mod drag_session;
pub(crate) mod drag_watcher;
mod file_transaction;
mod files;
mod imports;
mod links;
mod model;
mod positions;
mod storage;
mod window;
use base64::Engine;
use model::*;
pub use positions::Positions;
use serde_json::{json, Value};
use std::{path::PathBuf, sync::Mutex};
use storage::Storage;
use tauri::{Emitter, Manager};
use tauri_plugin_clipboard_manager::ClipboardExt;
#[derive(Default)]
pub struct Shelves(Mutex<Option<Storage>>);
pub const LEGACY_NOTICE: &str = "Shelf operations now use Shelferry. Existing Tooki shelves are preserved and have not been migrated. Open Shelferry from Tooki or use the shelferry CLI.";
pub fn initialize_legacy_links(app: &tauri::AppHandle) {
    links::initialize(app);
}
#[tauri::command]
pub async fn shelf_request() -> Result<Value, String> {
    Err(LEGACY_NOTICE.into())
}
pub(crate) fn request(
    _app: &tauri::AppHandle,
    _operation: &str,
    _args: Value,
) -> Result<Value, String> {
    Err(LEGACY_NOTICE.into())
}
fn required<'a>(args: &'a Value, key: &str) -> Result<&'a str, String> {
    args[key].as_str().ok_or_else(|| format!("Missing {key}"))
}
fn legacy_request(app: &tauri::AppHandle, operation: &str, args: Value) -> Result<Value, String> {
    if operation == "addFiles" {
        return imports::add_files(app, args);
    }
    if actions::handles(operation) {
        return actions::run(app, operation, args);
    }
    let state = app.state::<Shelves>();
    let mut guard = state.0.lock().map_err(|e| e.to_string())?;
    if guard.is_none() {
        *guard = Some(Storage::open(
            app.path()
                .app_data_dir()
                .map_err(|e| e.to_string())?
                .join("shelf"),
        )?);
    }
    let store = guard.as_mut().unwrap();
    if operation == "list" {
        return Ok(
            json!({"shelves":store.library.shelves,"capabilities":crate::platform::file_capabilities(),"settings":store.library.settings,"shelfCapabilities":drag_watcher::capabilities(),"imageConversion":cfg!(target_os="macos")}),
        );
    }
    let mut next = store.library.clone();
    if operation == "saveSettings" {
        next.settings =
            serde_json::from_value(args).map_err(|e| format!("Invalid Shelf settings: {e}"))?;
        if next.settings.show_on_shift_drag && !drag_watcher::available() {
            return Err("Global drag detection is unavailable on this platform.".into());
        }
        let enabled = next.settings.enabled;
        let watch = enabled && drag_watcher::available();
        let previous_watch = store.library.settings.enabled && drag_watcher::available();
        drag_watcher::configure(app, watch)?;
        if let Err(error) = store.save(next) {
            let _ = drag_watcher::configure(app, previous_watch);
            return Err(error);
        }
        drop(guard);
        crate::applications::preferences::sync_tool_shortcuts(app, "shelf", enabled);
        if !enabled {
            for (label, window) in app.webview_windows() {
                if label.starts_with("shelf-") {
                    let _ = window.close();
                }
            }
        }
        let _ = app.emit("shelf-changed", ());
        return Ok(Value::Null);
    }
    if !next.settings.enabled && !matches!(operation, "summary" | "detail" | "discardEmpty") {
        return Err("Shelf is disabled. Enable it in Settings → Shelf.".into());
    }
    if operation == "prepareConversion" {
        return conversion::prepare(store, required(&args, "shelf")?, &args);
    }
    if operation == "saveConversion" {
        let value = conversion::save(
            store,
            required(&args, "shelf")?,
            required(&args, "session")?,
            args["replace"].as_bool().unwrap_or(false),
        )?;
        let _ = app.emit("shelf-changed", ());
        return Ok(value);
    }
    if operation == "create" {
        let shelf = Shelf {
            id: identifier(),
            name: name(args["name"].as_str().unwrap_or("New Shelf"))?,
            items: vec![],
        };
        let id = shelf.id.clone();
        next.shelves.push(shelf);
        store.save(next)?;
        let _ = app.emit("shelf-changed", ());
        return Ok(json!(id));
    }
    let shelf_id = required(&args, "shelf")?;
    let index = next
        .shelves
        .iter()
        .position(|s| s.id == shelf_id)
        .ok_or("Shelf not found")?;
    let shelf = &mut next.shelves[index];
    if operation == "renameItem" {
        store.rename_file(shelf_id, required(&args, "item")?, required(&args, "name")?)?;
        let _ = app.emit("shelf-changed", ());
        return Ok(Value::Null);
    }
    if operation == "thumbnail" {
        let path = shelf
            .items
            .iter()
            .find(|i| Some(i.id.as_str()) == args["item"].as_str())
            .ok_or("Item not found")?
            .path
            .clone();
        drop(guard);
        return Ok(json!(crate::platform::shelf::content::thumbnail(&path)));
    }
    if operation == "show" {
        let title = shelf.name.clone();
        drop(guard);
        return window::show(app, shelf_id, &title).map(|_| Value::Null);
    }
    if operation == "summary" {
        let bytes: u64 = shelf
            .items
            .iter()
            .filter_map(|item| std::fs::metadata(&item.path).ok())
            .filter(|m| m.is_file())
            .map(|m| m.len())
            .sum();
        return Ok(
            json!({"bytes":bytes,"items":shelf.items.iter().map(|item|json!({"id":item.id,"bytes":std::fs::metadata(&item.path).ok().filter(|m|m.is_file()).map(|m|m.len())})).collect::<Vec<_>>()}),
        );
    }
    if operation == "finishDrag" {
        let ids: Vec<String> =
            serde_json::from_value(args["items"].clone()).map_err(|e| e.to_string())?;
        if next.finish_drag(
            shelf_id,
            &ids,
            args["dropped"].as_bool().unwrap_or(false),
            now_seconds(),
        ) {
            store.save(next)?;
            let _ = app.emit("shelf-changed", ());
        }
        return Ok(Value::Null);
    }
    if operation == "dragAll" {
        let selected: Vec<_> = shelf
            .items
            .iter()
            .filter(|i| {
                args["items"]
                    .as_array()
                    .is_none_or(|ids| ids.contains(&json!(i.id)))
            })
            .collect();
        let paths: Vec<_> = selected.iter().map(|i| i.path.clone()).collect();
        if paths.is_empty() || paths.iter().any(|p| !std::path::Path::new(p).exists()) {
            return Err("Some files are unavailable.".into());
        }
        return Ok(
            json!({"items":selected.iter().map(|i| &i.id).collect::<Vec<_>>(),"paths":paths,"icon":format!("data:image/png;base64,{}",base64::engine::general_purpose::STANDARD.encode(include_bytes!("../../icons/icon.png")))}),
        );
    }
    let mut cleanup = vec![];
    match operation {
        "renameShelf" => shelf.name = name(required(&args, "name")?)?,
        "clear" => {
            cleanup = shelf.items.clone();
            shelf.items.clear();
        }
        "discardEmpty" if !shelf.items.is_empty() => return Ok(Value::Null),
        "deleteShelf" | "discardEmpty" => {
            cleanup = shelf.items.clone();
            next.shelves.remove(index);
        }
        "addContent" => {
            let content = &args["content"];
            let item = if let Some(png) = content["png"].as_str() {
                let bytes = base64::engine::general_purpose::STANDARD
                    .decode(png)
                    .map_err(|e| e.to_string())?;
                store.bytes("Image.png", &bytes)?
            } else if let Some(url) = content["url"].as_str() {
                let escaped = url
                    .replace('&', "&amp;")
                    .replace('<', "&lt;")
                    .replace('>', "&gt;")
                    .replace('"', "&quot;");
                #[cfg(target_os="macos")]
                let (filename, text) = ("Link.webloc",format!("<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>URL</key><string>{escaped}</string></dict></plist>"));
                #[cfg(not(target_os = "macos"))]
                let (filename, text) = ("Link.url", format!("[InternetShortcut]\nURL={url}\n"));
                {
                    let mut item = store.bytes(filename, text.as_bytes())?;
                    item.text = Some(url.into());
                    item.is_link = true;
                    item
                }
            } else {
                store.text(
                    content["text"]
                        .as_str()
                        .ok_or("No supported content to paste.")?,
                )?
            };
            cleanup.push(item.clone());
            shelf.items.push(item);
        }
        "addText" => {
            let item = store.text(required(&args, "text")?)?;
            cleanup.push(item.clone());
            shelf.items.push(item);
        }
        _ => {
            let item_id = required(&args, "item")?;
            let item_index = shelf
                .items
                .iter()
                .position(|i| i.id == item_id)
                .ok_or("Item not found")?;
            let item = shelf.items[item_index].clone();
            match operation {
                "remove" => {
                    cleanup.push(item);
                    shelf.items.remove(item_index);
                }
                "copyPath" => {
                    drop(guard);
                    app.clipboard()
                        .write_text(item.path)
                        .map_err(|e| e.to_string())?;
                    return Ok(Value::Null);
                }
                "detail" => {
                    let path = PathBuf::from(&item.path);
                    let metadata = path.metadata().ok();
                    let text = if metadata
                        .as_ref()
                        .is_some_and(|m| m.is_file() && m.len() < 1024 * 1024)
                    {
                        std::fs::read_to_string(&path).ok()
                    } else {
                        None
                    };
                    let image = if metadata
                        .as_ref()
                        .is_some_and(|m| m.is_file() && m.len() < 10 * 1024 * 1024)
                    {
                        let mime = match path
                            .extension()
                            .and_then(|s| s.to_str())
                            .unwrap_or("")
                            .to_ascii_lowercase()
                            .as_str()
                        {
                            "png" => Some("image/png"),
                            "jpg" | "jpeg" => Some("image/jpeg"),
                            "webp" => Some("image/webp"),
                            "gif" => Some("image/gif"),
                            _ => None,
                        };
                        mime.and_then(|mime| {
                            std::fs::read(&path).ok().map(|bytes| {
                                format!(
                                    "data:{mime};base64,{}",
                                    base64::engine::general_purpose::STANDARD.encode(bytes)
                                )
                            })
                        })
                    } else {
                        None
                    };
                    return Ok(
                        json!({"item":item,"exists":metadata.is_some(),"bytes":metadata.as_ref().map(|m|m.len()),"text":text,"image":image}),
                    );
                }
                "drag" => {
                    if !PathBuf::from(&item.path).exists() {
                        return Err("File no longer exists.".into());
                    }
                    return Ok(
                        json!({"items":[item.id],"path":item.path,"icon":format!("data:image/png;base64,{}",base64::engine::general_purpose::STANDARD.encode(include_bytes!("../../icons/icon.png")))}),
                    );
                }
                "open" | "preview" | "apps" | "reveal" | "revealOriginal" | "copyFile" => {
                    drop(guard);
                    return crate::platform::file_action(
                        app,
                        if operation == "revealOriginal" {
                            "reveal"
                        } else {
                            operation
                        },
                        &PathBuf::from(if operation == "revealOriginal" {
                            item.original_path.ok_or("No original file")?
                        } else {
                            item.path
                        }),
                        args["app"].as_str(),
                    );
                }
                _ => return Err("Unknown Shelf operation".into()),
            }
        }
    }
    let adding = matches!(operation, "addFiles" | "addText" | "addContent");
    if let Err(error) = store.save(next) {
        if adding {
            for item in &cleanup {
                store.remove_owned(item);
            }
        }
        return Err(error);
    }
    if !adding {
        for item in &cleanup {
            store.remove_owned(item);
        }
    }
    if matches!(operation, "deleteShelf" | "discardEmpty") {
        if let Some(window) = app.get_webview_window(&format!("shelf-{shelf_id}")) {
            let _ = window.close();
        }
    }
    let _ = app.emit("shelf-changed", ());
    Ok(Value::Null)
}

pub fn initialize(app: &tauri::AppHandle) {
    positions::initialize(app);
    let handle = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        match request(&handle, "list", json!({})) {
            Ok(library) => {
                let watch = library["settings"]["enabled"].as_bool().unwrap_or(false)
                    && drag_watcher::available();
                if let Err(e) = drag_watcher::configure(&handle, watch) {
                    eprintln!("Shelf drag detection: {e}");
                }
            }
            Err(e) => eprintln!("Shelf: {e}"),
        }
        // Persistent retirement survives quitting during the receiver's grace period.
        loop {
            if let Err(e) = cleanup_retired(&handle) {
                eprintln!("Shelf cleanup: {e}");
            }
            std::thread::sleep(std::time::Duration::from_secs(30));
        }
    });
    links::initialize(app);
}
fn cleanup_retired(app: &tauri::AppHandle) -> Result<(), String> {
    let state = app.state::<Shelves>();
    let mut guard = state.0.lock().map_err(|e| e.to_string())?;
    let Some(store) = guard.as_mut() else {
        return Ok(());
    };
    store.cleanup_retired(now_seconds())
}
pub fn handle_event(window: &tauri::Window, event: &tauri::WindowEvent) {
    positions::handle_event(window, event);
    drag_watcher::handle_window_event(window, event);
}
pub fn stop(app: &tauri::AppHandle) {
    drag_watcher::stop();
    positions::flush(app);
}
