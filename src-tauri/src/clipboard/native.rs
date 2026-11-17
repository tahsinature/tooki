use serde_json::Value;
use tauri::AppHandle;

#[cfg(target_os = "macos")]
pub fn call(operation: &str, payload: Value) -> Result<Value, String> {
    use std::ffi::{CStr, CString};
    unsafe extern "C" {
        fn tooki_clipboard(
            operation: *const std::ffi::c_char,
            input: *const std::ffi::c_char,
        ) -> *mut std::ffi::c_char;
        fn tooki_clipboard_free(value: *mut std::ffi::c_char);
    }
    let operation = CString::new(operation).map_err(|e| e.to_string())?;
    let input = CString::new(payload.to_string()).map_err(|e| e.to_string())?;
    // The bridge returns an owned UTF-8 JSON buffer; it never crosses an ObjC exception into Rust.
    let value = unsafe {
        let ptr = tooki_clipboard(operation.as_ptr(), input.as_ptr());
        if ptr.is_null() {
            return Err("Native clipboard returned no data".into());
        }
        let text = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        tooki_clipboard_free(ptr);
        text
    };
    let value: Value = serde_json::from_str(&value).map_err(|e| e.to_string())?;
    if let Some(error) = value.get("error").and_then(Value::as_str) {
        Err(error.into())
    } else {
        Ok(value)
    }
}
#[cfg(not(target_os = "macos"))]
pub fn call(_: &str, _: Value) -> Result<Value, String> {
    Err("Native clipboard integration is currently available on macOS only".into())
}

pub fn on_main(app: &AppHandle, operation: &str, payload: Value) -> Result<Value, String> {
    if operation == "paste" {
        crate::permissions::require_accessibility(app)?;
    }
    let (tx, rx) = std::sync::mpsc::sync_channel(1);
    let operation = operation.to_string();
    app.run_on_main_thread(move || {
        let _ = tx.send(call(&operation, payload));
    })
    .map_err(|e| e.to_string())?;
    rx.recv().map_err(|e| e.to_string())?
}
