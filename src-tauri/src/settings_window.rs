use tauri::{AppHandle, Emitter, Manager, WindowEvent};

#[tauri::command]
pub fn open_settings(app: AppHandle, page: Option<String>) -> Result<(), String> {
    crate::launcher_presentation::cancel(&app);
    let settings = app
        .get_webview_window("settings")
        .ok_or("Settings window is unavailable")?;
    if let Some(page) = page {
        if matches!(
            page.as_str(),
            "notes"
                | "general"
                | "appearance"
                | "applications"
                | "shortcuts"
                | "hyper"
                | "detective"
                | "clipboard"
                | "snippets"
                | "shelf"
                | "system"
                | "keepAwake"
                | "about"
        ) {
            let _ = settings.emit("settings-page", page);
        }
    }
    settings.unminimize().map_err(|e| e.to_string())?;
    settings.show().map_err(|e| e.to_string())?;
    settings.set_focus().map_err(|e| e.to_string())?;
    crate::launcher_presentation::dismiss_launcher(app)?;
    Ok(())
}

pub fn handle_event(window: &tauri::Window, event: &WindowEvent) {
    if window.label() != "settings" {
        return;
    }
    if let WindowEvent::CloseRequested { api, .. } = event {
        // Keep the dedicated webview and its position when closing Settings.
        api.prevent_close();
        crate::shortcut_detective::stop(window.app_handle());
        window
            .state::<crate::launcher_shortcut::LauncherShortcut>()
            .stop_recording();
        if let Err(error) = window.hide() {
            eprintln!("Could not hide Settings: {error}");
        }
    }
}

/// Install system controls once, before the transparent Settings window is shown.
pub fn initialize(app: &AppHandle) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        let window = app
            .get_webview_window("settings")
            .ok_or("Settings window is unavailable")?;
        unsafe extern "C" {
            fn tooki_settings_chrome(window: *mut std::ffi::c_void);
        }
        unsafe {
            tooki_settings_chrome(window.ns_window().map_err(|e| e.to_string())?);
        }
    }
    #[cfg(not(target_os = "macos"))]
    let _ = app;
    Ok(())
}
