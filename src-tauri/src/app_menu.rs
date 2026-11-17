use crate::popup_position::position;
use tauri::{Emitter, Manager, PhysicalPosition, WindowEvent};

#[derive(serde::Deserialize)]
pub struct Anchor {
    x: f64,
    y: f64,
    height: f64,
}

#[tauri::command]
pub fn toggle_app_menu(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    anchor: Anchor,
) -> Result<(), String> {
    if window.label() != "main" {
        return Err("The app menu belongs to Root Search.".into());
    }
    if ![anchor.x, anchor.y, anchor.height]
        .iter()
        .all(|value| value.is_finite())
    {
        return Err("Invalid menu anchor".into());
    }
    let popup = app
        .get_webview_window("app-menu")
        .ok_or("App menu is unavailable")?;
    if popup.is_visible().map_err(|e| e.to_string())? {
        dismiss(&app);
        return Ok(());
    }
    let origin = window.inner_position().map_err(|e| e.to_string())?;
    let scale = window.scale_factor().map_err(|e| e.to_string())?;
    let size = popup.outer_size().map_err(|e| e.to_string())?;
    let popup_scale = popup.scale_factor().map_err(|e| e.to_string())?;
    let anchor_x = origin.x as f64 + anchor.x * scale;
    let anchor_top = origin.y as f64 + anchor.y * scale;
    let anchor_bottom = anchor_top + anchor.height * scale;
    let monitor = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .ok_or("Display is unavailable")?;
    let area = monitor.work_area();
    let (x, y) = position(
        anchor_x,
        anchor_top,
        anchor_bottom,
        size.width as f64 / popup_scale * scale,
        size.height as f64 / popup_scale * scale,
        area.position.x as f64,
        area.position.y as f64,
        area.size.width as f64,
        area.size.height as f64,
        6.0 * scale,
    );
    popup
        .set_position(PhysicalPosition::new(x as i32, y as i32))
        .map_err(|e| e.to_string())?;
    popup.show().map_err(|e| e.to_string())?;
    popup.set_focus().map_err(|e| e.to_string())?;
    let _ = popup.emit("app-menu-opened", ());
    let _ = app.emit_to("main", "app-menu-visible", true);
    Ok(())
}
pub fn dismiss(app: &tauri::AppHandle) {
    if let Some(popup) = app.get_webview_window("app-menu") {
        let _ = popup.hide();
    }
    let _ = app.emit_to("main", "app-menu-visible", false);
}
#[tauri::command]
pub fn close_app_menu(app: tauri::AppHandle, restore_focus: bool) {
    dismiss(&app);
    if restore_focus {
        if let Some(main) = app.get_webview_window("main") {
            if main.is_visible().unwrap_or(false) {
                let _ = main.set_focus();
            }
        }
    }
}
pub fn handle_event(window: &tauri::Window, event: &WindowEvent) {
    if window.label() == "app-menu" {
        match event {
            WindowEvent::Focused(false) => dismiss(window.app_handle()),
            WindowEvent::CloseRequested { api, .. } => {
                api.prevent_close();
                dismiss(window.app_handle());
            }
            _ => (),
        }
    } else if window.label() == "main"
        && matches!(
            event,
            WindowEvent::Moved(_) | WindowEvent::Resized(_) | WindowEvent::CloseRequested { .. }
        )
    {
        dismiss(window.app_handle());
    }
}

#[tauri::command]
pub fn resize_app_menu(window: tauri::WebviewWindow, height: f64) -> Result<(), String> {
    if window.label() != "app-menu" || !height.is_finite() || !(50.0..=400.0).contains(&height) {
        return Err("Invalid menu size".into());
    }
    let scale = window.scale_factor().map_err(|e| e.to_string())?;
    let old_size = window.outer_size().map_err(|e| e.to_string())?;
    let origin = window.outer_position().map_err(|e| e.to_string())?;
    let monitor = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .ok_or("Display is unavailable")?;
    let area = monitor.work_area();
    let y = (origin.y as f64 + old_size.height as f64 - height * scale).clamp(
        area.position.y as f64,
        (area.position.y as f64 + area.size.height as f64 - height * scale)
            .max(area.position.y as f64),
    );
    window
        .set_size(tauri::LogicalSize::new(320.0, height))
        .map_err(|e| e.to_string())?;
    window
        .set_position(PhysicalPosition::new(origin.x, y as i32))
        .map_err(|e| e.to_string())
}
