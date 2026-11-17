use tauri_plugin_dialog::{DialogExt, MessageDialogButtons};
#[tauri::command]
pub async fn application_action(
    app: tauri::AppHandle,
    id: String,
    operation: String,
) -> Result<String, String> {
    let entry = super::find(&app, &id)?;
    tauri::async_runtime::spawn_blocking(move || {
        match operation.as_str() {
            "location" => Ok(super::platform::location(&entry.id)),
            "canUninstall" => Ok(super::platform::can_uninstall(&entry.id).to_string()),
            "reveal" => { super::platform::reveal(&entry.id)?; Ok(String::new()) }
            "uninstall" => {
                if !super::platform::can_uninstall(&entry.id) { return Err("Removal is unavailable for this application.".into()); }
                #[cfg(target_os = "macos")]
                {
                    let accepted = app.dialog().message(format!("Move {} to Trash?\n\nOnly the application bundle will be moved. Its documents and settings will remain. Quit the application first.", entry.name))
                        .title("Uninstall application?").buttons(MessageDialogButtons::OkCancelCustom("Move to Trash".into(), "Cancel".into())).blocking_show();
                    if !accepted { return Ok("Cancelled".into()); }
                }
                super::platform::uninstall(&entry.id)?;
                super::refresh(&app);
                Ok(if cfg!(target_os="macos") { "Application moved to Trash." } else { "Complete removal in the system application manager." }.into())
            }
            _ => Err("Unknown application action.".into())
        }
    }).await.map_err(|e| e.to_string())?
}
