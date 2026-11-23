//! Lifecycle of Tooki-owned windows. External-app tiling belongs in a separate
//! window-management service; it must not use these activation or hide policies.
use tauri::{AppHandle, Manager, WebviewWindow};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Role {
    Launcher,
    Workspace,
    Settings,
    OwnedPopup,
}

pub fn present(window: &WebviewWindow, role: Role) -> tauri::Result<()> {
    if role == Role::Settings {
        set_dock_visible(window.app_handle(), true)?;
    }
    // Native presentation raises only this window. Never raise all app windows.
    crate::platform::windows::present(window)
}

pub fn dismiss(window: &WebviewWindow, role: Role) -> tauri::Result<()> {
    if role != Role::OwnedPopup {
        crate::window_toggle::dismiss_popups(window.app_handle(), window.label());
        crate::platform::preview::close_window(window.app_handle(), window.label());
    }
    crate::platform::windows::dismiss(window)?;
    if role == Role::Settings {
        set_dock_visible(window.app_handle(), false)?;
    }
    Ok(())
}

// Preserve the current product policy: Settings participates in the Dock;
// launcher and floating workspaces remain available through shortcuts.
pub fn set_dock_visible(app: &AppHandle, visible: bool) -> tauri::Result<()> {
    #[cfg(target_os = "macos")]
    app.set_activation_policy(if visible {
        tauri::ActivationPolicy::Regular
    } else {
        tauri::ActivationPolicy::Accessory
    })?;
    #[cfg(not(target_os = "macos"))]
    let _ = (app, visible);
    Ok(())
}

/// Explicit popup dismissal may return focus to its visible owner. Focus loss
/// dismissal must not call this, because the user may have selected another app.
pub fn focus_owner(app: &AppHandle, label: &str) {
    if let Some(owner) = app.get_webview_window(label) {
        if owner.is_visible().unwrap_or(false) && !owner.is_minimized().unwrap_or(true) {
            let _ = crate::platform::windows::present(&owner);
        }
    }
}
