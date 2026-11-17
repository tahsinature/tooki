//! Shared native preview ownership and navigation. Feature views supply selection changes.
use serde_json::{json, Value};
use tauri::AppHandle;

#[cfg(target_os = "macos")]
pub fn initialize(app: &AppHandle) {
    use std::ffi::{c_char, CStr};
    use std::sync::OnceLock;
    use tauri::Emitter;
    static APP: OnceLock<AppHandle> = OnceLock::new();
    extern "C" fn navigate(
        owner: *const c_char,
        context: *const c_char,
        direction: i32,
        extend: bool,
    ) {
        if owner.is_null() || context.is_null() {
            return;
        }
        if let Some(app) = APP.get() {
            let owner = unsafe { CStr::from_ptr(owner) }.to_string_lossy();
            let context = unsafe { CStr::from_ptr(context) }.to_string_lossy();
            let _ = app.emit_to(
                owner.as_ref(),
                "quick-look-navigation",
                json!({
                    "context":context,"direction":direction,"extend":extend
                }),
            );
        }
    }
    unsafe extern "C" {
        fn tooki_preview_initialize(
            callback: extern "C" fn(*const c_char, *const c_char, i32, bool),
        );
    }
    let _ = APP.set(app.clone());
    unsafe {
        tooki_preview_initialize(navigate);
    }
}
#[cfg(not(target_os = "macos"))]
pub fn initialize(_: &AppHandle) {}

pub fn active(app: &AppHandle, owner: &str, context: &str) -> Result<bool, String> {
    #[cfg(target_os = "macos")]
    return crate::clipboard::native::on_main(
        app,
        "previewActive",
        json!({"owner":owner,"context":context}),
    )
    .map(|v| v["active"] == true);
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (app, owner, context);
        Ok(false)
    }
}

pub fn show(
    app: &AppHandle,
    owner: &str,
    context: &str,
    paths: Value,
    update: bool,
) -> Result<Value, String> {
    crate::clipboard::native::on_main(
        app,
        if update { "previewUpdate" } else { "preview" },
        json!({"owner":owner,"context":context,"paths":paths}),
    )
}

#[tauri::command]
pub async fn close_preview(
    app: AppHandle,
    window: tauri::WebviewWindow,
    context: String,
) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    return tauri::async_runtime::spawn_blocking(move || {
        crate::clipboard::native::on_main(
            &app,
            "previewClose",
            json!({"owner":window.label(),"context":context}),
        )
        .map(|_| ())
    })
    .await
    .map_err(|e| e.to_string())?;
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (app, window, context);
        Ok(())
    }
}

/// Schedule cleanup without blocking AppKit window callbacks.
pub fn close_window(app: &AppHandle, owner: &str) {
    #[cfg(target_os = "macos")]
    {
        let payload = json!({"owner":owner});
        let _ = app.run_on_main_thread(move || {
            let _ = crate::clipboard::native::call("previewCloseOwner", payload);
        });
    }
    #[cfg(not(target_os = "macos"))]
    let _ = (app, owner);
}
