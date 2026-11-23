#[cfg(target_os = "macos")]
pub fn initialize(app: &tauri::AppHandle) {
    use std::sync::OnceLock;
    static APP: OnceLock<tauri::AppHandle> = OnceLock::new();
    extern "C" fn open_root() {
        if let Some(app) = APP.get() {
            let app = app.clone();
            tauri::async_runtime::spawn(async move {
                if let Err(error) = crate::launcher_presentation::return_to_root_search(app).await {
                    eprintln!("Could not return to root search: {error}");
                }
            });
        }
    }
    unsafe extern "C" {
        fn tooki_root_search_shortcut_initialize(callback: extern "C" fn());
    }
    let _ = APP.set(app.clone());
    unsafe { tooki_root_search_shortcut_initialize(open_root); }
}
#[cfg(not(target_os = "macos"))]
pub fn initialize(_: &tauri::AppHandle) {}
