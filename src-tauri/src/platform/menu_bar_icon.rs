//! Install Tooki's native menu-bar artwork without changing Tauri's menu/events.
#[cfg(target_os = "macos")]
pub fn install(tray: &tauri::tray::TrayIcon) -> Result<(), String> {
    tray.with_inner_tray_icon(|inner| {
        let item = inner
            .ns_status_item()
            .ok_or("Menu-bar item is unavailable")?;
        unsafe extern "C" {
            fn tooki_set_menu_bar_icon(item: *mut std::ffi::c_void, development: bool) -> bool;
        }
        // with_inner_tray_icon runs on AppKit's main thread. The retained item
        // remains alive for the duration of the native call.
        let pointer = (&*item) as *const _ as *mut std::ffi::c_void;
        if unsafe { tooki_set_menu_bar_icon(pointer, cfg!(debug_assertions)) } {
            Ok(())
        } else {
            Err("Could not install Tooki menu-bar icon")
        }
    })
    .map_err(|error| error.to_string())?
    .map_err(str::to_owned)
}

/// Use AppKit's scalable outline mug while retaining Tauri's menu and lifetime.
#[cfg(target_os = "macos")]
pub fn install_keep_awake(tray: &tauri::tray::TrayIcon) -> Result<(), String> {
    tray.with_inner_tray_icon(|inner| {
        let item = inner
            .ns_status_item()
            .ok_or("Menu-bar item is unavailable")?;
        unsafe extern "C" {
            fn tooki_set_keep_awake_icon(item: *mut std::ffi::c_void) -> bool;
        }
        let pointer = (&*item) as *const _ as *mut std::ffi::c_void;
        if unsafe { tooki_set_keep_awake_icon(pointer) } {
            Ok(())
        } else {
            Err("Could not install Keep Awake menu-bar icon")
        }
    })
    .map_err(|error| error.to_string())?
    .map_err(str::to_owned)
}
