#[cfg(target_os = "macos")]
use tauri::Manager;
/// Shared native utility behavior without replacing Wry's window class.
fn attach(window: &tauri::WebviewWindow) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_utility_attach(window: *mut std::ffi::c_void);
        }
        let window = window.clone();
        let app = window.app_handle().clone();
        app.run_on_main_thread(move || {
            if let Ok(pointer) = window.ns_window() {
                unsafe {
                    tooki_utility_attach(pointer);
                }
            }
        })
        .map_err(|e| e.to_string())?;
    }
    #[cfg(not(target_os = "macos"))]
    let _ = window;
    Ok(())
}

/// Shared material for compact utility windows. Other platforms keep the themed surface.
pub fn apply(window: &tauri::WebviewWindow) -> Result<(), String> {
    let theme: serde_json::Value =
        serde_json::from_str(include_str!("../../../src/lib/themes/graphite.json"))
            .map_err(|error| error.to_string())?;
    let radius = theme["tokens"]["cornerRadius"]
        .as_f64()
        .ok_or("Missing default corner radius")?;
    attach(window)?;
    apply_radius(window, radius)
}

fn apply_radius(window: &tauri::WebviewWindow, radius: f64) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    window
        .set_effects(tauri::utils::config::WindowEffectsConfig {
            effects: vec![tauri::utils::WindowEffect::UnderWindowBackground],
            radius: Some(radius),
            state: Some(tauri::utils::WindowEffectState::Active),
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;
    #[cfg(not(target_os = "macos"))]
    let _ = (window, radius);
    Ok(())
}

#[tauri::command]
pub fn set_window_corner_radius(window: tauri::WebviewWindow, radius: f64) -> Result<(), String> {
    if window.label() != "notes" && !window.label().starts_with("shelf-") {
        return Err("Only floating utility windows use this material.".into());
    }
    if !radius.is_finite() || !(0.0..=24.0).contains(&radius) {
        return Err("Corner radius must be between 0 and 24.".into());
    }
    apply_radius(&window, radius)
}

#[tauri::command]
pub fn set_utility_on_top(window: tauri::WebviewWindow, enabled: bool) -> Result<(), String> {
    if window.label() != "notes" && !window.label().starts_with("shelf-") {
        return Err("Not a utility window".into());
    }
    window
        .set_always_on_top(enabled || crate::shelf::drag_watcher::is_temporary(window.label()))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn resize_utility_window(
    window: tauri::WebviewWindow,
    width: f64,
    height: f64,
    animate: bool,
) -> Result<(), String> {
    if window.label() != "notes" && !window.label().starts_with("shelf-") {
        return Err("Not a utility window".into());
    }
    if !width.is_finite()
        || !height.is_finite()
        || !(100.0..=2000.0).contains(&width)
        || !(80.0..=2000.0).contains(&height)
    {
        return Err("Invalid utility window size".into());
    }
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_utility_resize(
                window: *mut std::ffi::c_void,
                width: f64,
                height: f64,
                animate: bool,
            );
        }
        let app = window.app_handle().clone();
        app.run_on_main_thread(move || {
            if let Ok(pointer) = window.ns_window() {
                unsafe {
                    tooki_utility_resize(pointer, width, height, animate);
                }
            }
        })
        .map_err(|e| e.to_string())
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = animate;
        window
            .set_size(tauri::LogicalSize::new(width, height))
            .map_err(|e| e.to_string())
    }
}
