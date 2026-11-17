mod catalog;
use serde_json::{json, Value};
use std::{fs, sync::Mutex};
use tauri::Manager;
use tauri_plugin_clipboard_manager::ClipboardExt;

static RECENTS_LOCK: Mutex<()> = Mutex::new(());

fn recent(app: &tauri::AppHandle) -> Result<Vec<String>, String> {
    let path = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("emoji/recents.json");
    match fs::read(path) {
        Ok(bytes) => serde_json::from_slice(&bytes).map_err(|e| e.to_string()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
        Err(error) => Err(error.to_string()),
    }
}
fn remember(app: &tauri::AppHandle, character: &str) -> Result<(), String> {
    let _guard = RECENTS_LOCK.lock().map_err(|e| e.to_string())?;
    let mut items = recent(app)?;
    items.retain(|item| item != character);
    items.insert(0, character.into());
    items.truncate(20);
    let directory = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("emoji");
    fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
    let temporary = directory.join("recents.tmp");
    fs::write(
        &temporary,
        serde_json::to_vec(&items).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    fs::rename(temporary, directory.join("recents.json")).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn emoji_request(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    operation: String,
    character: Option<String>,
) -> Result<Value, String> {
    if window.label() != "main" {
        return Err("Open Emoji Picker from the launcher.".into());
    }
    tauri::async_runtime::spawn_blocking(move || {
        if operation == "list" {
            return Ok(json!({"items":catalog::all(), "groups":catalog::GROUPS, "recent":recent(&app)?, "canPaste":cfg!(target_os="macos")}));
        }
        if !["copy", "paste", "shortcode"].contains(&operation.as_str()) { return Err("Unknown emoji action.".into()); }
        if operation == "paste" && !cfg!(target_os="macos") { return Err("Paste is not supported on this platform. Copy the emoji instead.".into()); }
        let item = catalog::all().iter().find(|item| Some(&item.character) == character.as_ref()).ok_or("Choose an available emoji first.")?;
        let text = if operation == "shortcode" { format!(":{}:", item.shortcode) } else { item.character.clone() };
        app.clipboard().write_text(text).map_err(|e| e.to_string())?;
        if operation == "paste" { crate::clipboard::native::on_main(&app, "paste", json!({}))?; }
        // A history write failure must not turn a completed copy/paste into a failed action.
        if let Err(error) = remember(&app, &item.character) { eprintln!("Could not save recent emoji: {error}"); }
        crate::launcher_presentation::dismiss_launcher(app)?;
        Ok(Value::Null)
    }).await.map_err(|e| e.to_string())?
}
