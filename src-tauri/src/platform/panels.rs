//! macOS panel integration is isolated here. Pin and review tauri-nspanel when
//! upgrading Tauri: it owns the native class conversion and activation tag.
use tauri::{AppHandle, Manager};
use tauri_nspanel::{tauri_panel, ManagerExt, WebviewWindowExt};
use tauri_nspanel::objc2_app_kit::{NSWindowCollectionBehavior, NSWindowStyleMask};

tauri_panel! {
    panel!(TookiTransientPanel {
        config: {
            can_become_key_window: true,
            can_become_main_window: false,
            becomes_key_only_if_needed: false,
            hides_on_deactivate: false,
            is_floating_panel: true
        }
    })
}

pub fn initialize(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    app.plugin(tauri_nspanel::init())?;
    for label in ["main", "app-menu", "filter-popup"] {
        let window = app.get_webview_window(label).ok_or("Panel window is unavailable")?;
        let panel = window.to_panel::<TookiTransientPanel>()?;
        let native = panel.as_panel();
        panel.set_style_mask(native.styleMask() | NSWindowStyleMask::NonactivatingPanel)?;
        panel.set_collection_behavior(
            NSWindowCollectionBehavior::MoveToActiveSpace
                | NSWindowCollectionBehavior::FullScreenAuxiliary,
        );
        panel.set_level(if label == "main" { 3 } else { 4 });
        panel.set_released_when_closed(false);
    }
    initialize_dismissal(app)?;
    Ok(())
}

// All callers run on the AppKit main thread. Keep the existing responder so
// returning from a popup does not discard the webview's focused input.
pub fn present(app: &AppHandle, label: &str) -> bool {
    let Ok(panel) = app.get_webview_panel(label) else { return false; };
    panel.order_front_regardless();
    panel.make_key_window();
    true
}

pub fn dismiss(app: &AppHandle, label: &str) -> bool {
    let Ok(panel) = app.get_webview_panel(label) else { return false; };
    panel.hide();
    true
}

fn initialize_dismissal(app: &AppHandle) -> tauri::Result<()> {
    use std::sync::OnceLock;
    static APP: OnceLock<AppHandle> = OnceLock::new();
    extern "C" fn dismiss() {
        if let Some(app) = APP.get() {
            // Route through the shared lifecycle, including owned-popup cleanup.
            let handle = app.clone();
            let _ = app.run_on_main_thread(move || {
                if let Err(error) = crate::launcher_presentation::dismiss(&handle) {
                    eprintln!("Could not dismiss launcher: {error}");
                }
            });
        }
    }
    unsafe extern "C" {
        fn tooki_panel_dismiss_initialize(
            launcher: *mut std::ffi::c_void,
            menu: *mut std::ffi::c_void,
            filter: *mut std::ffi::c_void,
            callback: extern "C" fn(),
        );
    }
    let _ = APP.set(app.clone());
    unsafe {
        tooki_panel_dismiss_initialize(
            app.get_webview_window("main").unwrap().ns_window()?,
            app.get_webview_window("app-menu").unwrap().ns_window()?,
            app.get_webview_window("filter-popup").unwrap().ns_window()?,
            dismiss,
        );
    }
    Ok(())
}
