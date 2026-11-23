use tauri::WebviewWindow;
#[cfg(target_os = "macos")]
use tauri::Manager;

pub fn present(window: &WebviewWindow) -> tauri::Result<()> {
    #[cfg(target_os = "macos")]
    {
        let pointer = window.ns_window()? as usize;
        let app = window.app_handle().clone();
        let label = window.label().to_string();
        window.run_on_main_thread(move || unsafe {
            unsafe extern "C" {
                fn tooki_window_present(window: *mut std::ffi::c_void);
            }
            if !super::panels::present(&app, &label) {
                tooki_window_present(pointer as *mut _);
            }
        })?;
    }
    #[cfg(not(target_os = "macos"))]
    {
        window.unminimize()?;
        window.show()?;
        window.set_focus()?;
    }
    Ok(())
}

pub fn dismiss(window: &WebviewWindow) -> tauri::Result<()> {
    #[cfg(target_os = "macos")]
    {
        let pointer = window.ns_window()? as usize;
        let app = window.app_handle().clone();
        let label = window.label().to_string();
        window.run_on_main_thread(move || unsafe {
            unsafe extern "C" {
                fn tooki_window_dismiss(window: *mut std::ffi::c_void);
            }
            if !super::panels::dismiss(&app, &label) {
                tooki_window_dismiss(pointer as *mut _);
            }
        })?;
    }
    #[cfg(not(target_os = "macos"))]
    window.hide()?;
    Ok(())
}
