//! Nonactivating native feedback, independent of launcher visibility.
pub fn show(app: &tauri::AppHandle, message: &str, failed: bool) {
    show_for_window(app, "main", message, failed);
}

pub fn show_for_window(app: &tauri::AppHandle, owner: &str, message: &str, failed: bool) {
    #[cfg(target_os = "macos")]
    {
        use tauri::Manager;
        let Ok(message) = std::ffi::CString::new(message) else {
            return;
        };
        let source = app
            .get_webview_window(owner)
            .and_then(|window| window.ns_window().ok())
            .map_or(0, |pointer| pointer as usize);
        if let Err(error) = app.run_on_main_thread(move || unsafe {
            unsafe extern "C" {
                fn tooki_toast_show(
                    source: *mut std::ffi::c_void,
                    message: *const std::ffi::c_char,
                    failed: bool,
                );
            }
            tooki_toast_show(source as *mut _, message.as_ptr(), failed);
        }) {
            eprintln!("Could not show command feedback: {error}");
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (app, owner, failed);
        eprintln!("{message}");
    }
}
