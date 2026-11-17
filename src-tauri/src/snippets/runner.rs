use super::*;

pub(super) async fn run(app: &tauri::AppHandle, args: &Value) -> Result<(), String> {
    let action = args["action"].as_str().unwrap_or("copy");
    if !["copy", "paste", "expand"].contains(&action) {
        return Err("Unknown snippet action.".into());
    }
    let state = app.state::<Snippets>();
    let ticket = args["ticket"]
        .as_u64()
        .ok_or("Wait for the preview to finish.")?;
    let result = state
        .prepared
        .lock()
        .unwrap()
        .remove(&ticket)
        .ok_or("Preview expired. Change an input or reselect the snippet.")?;
    if result.created.elapsed().as_secs() > 300 {
        return Err("Preview expired. Reselect the snippet.".into());
    }
    let current = record(app, &result.id)?;
    if current.revision != result.revision || !current.configuration.enabled {
        return Err("The snippet changed. Reselect it before running.".into());
    }
    if action == "expand" {
        if result.context.is_empty() {
            return Err("There is no automatic expansion to finish.".into());
        }
        let committed = automatic::commit(app, &result.context, &result.text, true).await;
        if let Err(error) = committed {
            if let Some(window) = app.get_webview_window("main") {
                let _ = crate::platform::launcher::present(&window);
            }
            return Err(error);
        }
    } else {
        app.clipboard()
            .write_text(result.text)
            .map_err(|e| e.to_string())?;
        if action == "paste" {
            if result.pid <= 0 {
                return Err("Copied. The previous app is unavailable; paste manually.".into());
            }
            let handle = app.clone();
            let pid = result.pid;
            tauri::async_runtime::spawn_blocking(move || {
                crate::clipboard::native::on_main(&handle, "paste", json!({"targetPid":pid}))
            })
            .await
            .map_err(|e| e.to_string())??;
        }
        native::call(app, "cancel", json!({})).await?;
    }
    *state.pending.lock().unwrap() = None;
    crate::launcher_presentation::dismiss_launcher(app.clone())
}
