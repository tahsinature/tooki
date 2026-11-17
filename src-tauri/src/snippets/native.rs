use serde_json::Value;
use tauri::AppHandle;

pub async fn call(app: &AppHandle, operation: &str, args: Value) -> Result<Value, String> {
    let (sender, receiver) = tokio::sync::oneshot::channel();
    let operation = operation.to_string();
    app.run_on_main_thread(move || {
        let _ = sender.send(on_main(&operation, args));
    })
    .map_err(|e| e.to_string())?;
    receiver.await.map_err(|e| e.to_string())?
}
#[cfg(target_os = "macos")]
fn on_main(operation: &str, args: Value) -> Result<Value, String> {
    use std::ffi::{CStr, CString};
    unsafe extern "C" {
        fn tooki_snippets(
            operation: *const std::ffi::c_char,
            args: *const std::ffi::c_char,
            callback: extern "C" fn(*const std::ffi::c_char),
        ) -> *mut std::ffi::c_char;
        fn tooki_clipboard_free(value: *mut std::ffi::c_char);
    }
    let operation = CString::new(operation).map_err(|e| e.to_string())?;
    let args = CString::new(args.to_string()).map_err(|e| e.to_string())?;
    let value = unsafe {
        let pointer = tooki_snippets(
            operation.as_ptr(),
            args.as_ptr(),
            super::automatic::received,
        );
        if pointer.is_null() {
            return Err("Native snippet service returned no response.".into());
        }
        let json = CStr::from_ptr(pointer).to_string_lossy().into_owned();
        tooki_clipboard_free(pointer);
        json
    };
    let value: Value = serde_json::from_str(&value).map_err(|e| e.to_string())?;
    if let Some(error) = value["error"].as_str() {
        Err(error.into())
    } else {
        Ok(value)
    }
}
#[cfg(not(target_os = "macos"))]
fn on_main(operation: &str, _: Value) -> Result<Value, String> {
    unsupported(operation)
}
#[cfg(any(not(target_os = "macos"), test))]
fn unsupported(operation: &str) -> Result<Value, String> {
    if ["configure", "status", "cancel"].contains(&operation) {
        Ok(serde_json::json!({"supported":false,"active":false,"permission":false}))
    } else {
        Err(
            "Automatic expansion and pasting are supported on macOS. You can still copy snippets."
                .into(),
        )
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn unsupported_platforms_keep_the_library_usable_and_fail_closed_on_expansion() {
        for operation in ["configure", "status", "cancel"] {
            let status = super::unsupported(operation).unwrap();
            assert_eq!(status["supported"], false);
            assert_eq!(status["active"], false);
        }
        for operation in ["permission", "commit", "activate", "current"] {
            assert!(super::unsupported(operation).is_err());
        }
    }
}
