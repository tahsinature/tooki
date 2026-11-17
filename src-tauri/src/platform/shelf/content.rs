use serde_json::Value;
use tauri::AppHandle;

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn tooki_shelf_thumbnail(path: *const std::ffi::c_char) -> *mut std::ffi::c_char;
    fn tooki_shelf_pasteboard(drag: bool) -> *mut std::ffi::c_char;
    fn tooki_clipboard_free(value: *mut std::ffi::c_char);
}
#[cfg(target_os = "macos")]
unsafe fn take_string(pointer: *mut std::ffi::c_char) -> Option<String> {
    if pointer.is_null() {
        return None;
    }
    let value = unsafe { std::ffi::CStr::from_ptr(pointer) }
        .to_string_lossy()
        .into_owned();
    unsafe {
        tooki_clipboard_free(pointer);
    }
    Some(value)
}
pub fn thumbnail(path: &str) -> Option<String> {
    #[cfg(target_os = "macos")]
    {
        let path = std::ffi::CString::new(path).ok()?;
        unsafe { take_string(tooki_shelf_thumbnail(path.as_ptr())) }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = path;
        None
    }
}
pub fn pasteboard(app: &AppHandle, drag: bool) -> Result<Value, String> {
    #[cfg(target_os = "macos")]
    {
        let (tx, rx) = std::sync::mpsc::sync_channel(1);
        app.run_on_main_thread(move || {
            let text = unsafe { take_string(tooki_shelf_pasteboard(drag)) }.unwrap_or_default();
            let _ = tx.send(serde_json::from_str(&text).map_err(|e| e.to_string()));
        })
        .map_err(|e| e.to_string())?;
        rx.recv().map_err(|e| e.to_string())?
    }
    #[cfg(not(target_os = "macos"))]
    {
        use tauri_plugin_clipboard_manager::ClipboardExt;
        if drag {
            return Err("Native content drops are not supported by this adapter.".into());
        }
        app.clipboard()
            .read_text()
            .map(|text| serde_json::json!({"text":text}))
            .map_err(|e| e.to_string())
    }
}
pub fn convert(args: Value) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_shelf_convert(input: *const std::ffi::c_char) -> *mut std::ffi::c_char;
        }
        let input = std::ffi::CString::new(args.to_string()).map_err(|e| e.to_string())?;
        match unsafe { take_string(tooki_shelf_convert(input.as_ptr())) } {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = args;
        Err("Image conversion is not available in this platform adapter yet.".into())
    }
}

/// Called directly from Tauri's main-thread DragDropEvent callback, before the pasteboard expires.
#[cfg(target_os = "macos")]
pub fn drag_snapshot() -> Result<Value, String> {
    let text = unsafe { take_string(tooki_shelf_pasteboard(true)) }.unwrap_or_default();
    serde_json::from_str(&text).map_err(|e| e.to_string())
}
#[cfg(target_os = "macos")]
pub fn drag_has_files() -> bool {
    unsafe extern "C" {
        fn tooki_shelf_drag_has_files() -> bool;
    }
    unsafe { tooki_shelf_drag_has_files() }
}

pub fn validate_image(path: &std::path::Path) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_shelf_validate_image(path: *const std::ffi::c_char) -> *mut std::ffi::c_char;
        }
        let path =
            std::ffi::CString::new(path.to_string_lossy().as_bytes()).map_err(|e| e.to_string())?;
        match unsafe { take_string(tooki_shelf_validate_image(path.as_ptr())) } {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = path;
        Err("Image conversion is unavailable on this platform.".into())
    }
}
