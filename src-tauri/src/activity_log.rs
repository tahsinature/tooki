use tauri::{AppHandle, WebviewWindow};
use tauri_plugin_dialog::DialogExt;

/// Only writes to a path explicitly selected in the native Save dialog.
#[tauri::command]
pub async fn export_activity_log(
    app: AppHandle,
    window: WebviewWindow,
    filename: String,
    contents: String,
) -> Result<bool, String> {
    if !matches!(window.label(), "settings" | "main") {
        return Err("This window cannot export activity logs.".into());
    }
    let filename = std::path::Path::new(&filename)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("activity-log.json")
        .to_owned();
    tauri::async_runtime::spawn_blocking(move || {
        let selected = app
            .dialog()
            .file()
            .set_parent(&window)
            .set_title("Export activity log")
            .set_file_name(filename)
            .add_filter("JSON", &["json"])
            .blocking_save_file();
        let Some(selected) = selected else {
            return Ok(false);
        };
        let path = selected.into_path().map_err(|e| e.to_string())?;
        std::fs::write(path, contents)
            .map_err(|e| format!("Could not export activity log: {e}"))?;
        Ok(true)
    })
    .await
    .map_err(|e| e.to_string())?
}
