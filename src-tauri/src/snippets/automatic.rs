use super::*;
use std::sync::OnceLock;
static APP: OnceLock<tauri::AppHandle> = OnceLock::new();
pub fn initialize(app: &tauri::AppHandle) {
    let _ = APP.set(app.clone());
    let handle = app.clone();
    tauri::async_runtime::spawn(async move {
        if let Err(error) = configure(&handle).await {
            eprintln!("Snippets: {error}");
        }
    });
}
pub extern "C" fn received(pointer: *const std::ffi::c_char) {
    if pointer.is_null() {
        return;
    }
    let payload = unsafe { std::ffi::CStr::from_ptr(pointer) }
        .to_string_lossy()
        .into_owned();
    let Some(app) = APP.get().cloned() else {
        return;
    };
    tauri::async_runtime::spawn(async move {
        if let Err(error) = handle(&app, &payload).await {
            let _ = app.emit("snippets-error", error);
        }
    });
}
async fn handle(app: &tauri::AppHandle, payload: &str) -> Result<(), String> {
    let data: Value = serde_json::from_str(payload).map_err(|e| e.to_string())?;
    let id = data["id"].as_str().ok_or("Missing snippet")?;
    let snippet = record(app, id)?;
    if !snippet.configuration.enabled
        || !snippet.configuration.automatic
        || !with_store(app, |s| s.preferences())?.automatic
    {
        return Ok(());
    }
    let context = data["context"].as_str().ok_or("Missing expansion target")?;
    let arguments = args_map(&data)?;
    let result = evaluate(&snippet, &arguments, &Context::now())?;
    let mut error = String::new();
    if let Some(text) = result.text {
        match commit(app, context, &text, false).await {
            Ok(()) => return Ok(()),
            Err(reason) => error = reason,
        }
    }
    // Continuing to type or moving to another field cancels this attempt.
    // Do not steal focus to show an obsolete argument form or failure.
    if native::call(app, "current", json!({"context":context}))
        .await?
        .as_bool()
        != Some(true)
    {
        return Ok(());
    }
    *app.state::<Snippets>().pending.lock().unwrap() = Some(Pending {
        id: id.into(),
        arguments,
        context: context.into(),
        error,
    });
    crate::launcher_presentation::request_tool(app, "command:snippets.open")
        .map_err(|e| e.to_string())
}
pub async fn commit(
    app: &tauri::AppHandle,
    context: &str,
    text: &str,
    activate: bool,
) -> Result<(), String> {
    if activate {
        native::call(app, "activate", json!({"context":context})).await?;
        // Wait for actual activation; the AX commit still revalidates field,
        // selection, and contents immediately before replacing anything.
        for _ in 0..60 {
            if native::call(app, "ready", json!({})).await?.as_bool() == Some(true) {
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(25)).await;
        }
    }
    native::call(app, "commit", json!({"context":context,"text":text})).await?;
    Ok(())
}
