use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{Emitter, Manager, PhysicalPosition, WindowEvent};

#[derive(Clone, Deserialize, Serialize)]
pub struct Anchor {
    x: f64,
    y: f64,
    height: f64,
}
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Request {
    session: String,
    id: String,
    value: String,
    label: String,
    placeholder: String,
    empty_message: String,
    anchor: Anchor,
}
struct Active {
    owner: String,
    request: Request,
}
#[derive(Default)]
pub struct FilterPopup(Mutex<Option<Active>>);

#[tauri::command]
pub fn open_filter_popup(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    request: Request,
) -> Result<(), String> {
    if window.label() == "filter-popup"
        || ![request.anchor.x, request.anchor.y, request.anchor.height]
            .iter()
            .all(|n| n.is_finite())
    {
        return Err("Invalid filter anchor".into());
    }
    dismiss(&app, None, false);
    let popup = app
        .get_webview_window("filter-popup")
        .ok_or("Filter window is unavailable")?;
    *app.state::<FilterPopup>()
        .0
        .lock()
        .map_err(|e| e.to_string())? = Some(Active {
        owner: window.label().into(),
        request: request.clone(),
    });
    popup
        .emit("filter-opened", &request)
        .map_err(|e| e.to_string())?;

    Ok(())
}
#[tauri::command]
pub fn filter_popup_request(app: tauri::AppHandle) -> Result<Option<Request>, String> {
    Ok(app
        .state::<FilterPopup>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .as_ref()
        .map(|active| active.request.clone()))
}
#[tauri::command]
pub fn query_filter_popup(
    app: tauri::AppHandle,
    session: String,
    query: String,
    request: u64,
) -> Result<(), String> {
    let state = app.state::<FilterPopup>();
    let guard = state.0.lock().map_err(|e| e.to_string())?;
    let active = guard
        .as_ref()
        .filter(|active| active.request.session == session)
        .ok_or("Filter is closed")?;
    app.emit_to(
        &active.owner,
        "filter-query",
        serde_json::json!({"session": session, "query": query, "request": request}),
    )
    .map_err(|e| e.to_string())
}
#[tauri::command]
pub fn close_filter_popup(
    app: tauri::AppHandle,
    session: String,
    value: Option<String>,
    restore: bool,
) {
    let matches = app
        .state::<FilterPopup>()
        .0
        .lock()
        .ok()
        .and_then(|active| {
            active
                .as_ref()
                .map(|active| active.request.session == session)
        })
        .unwrap_or(false);
    if matches {
        dismiss(&app, value, restore);
    }
}
pub fn dismiss(app: &tauri::AppHandle, value: Option<String>, restore: bool) {
    let active = app
        .state::<FilterPopup>()
        .0
        .lock()
        .ok()
        .and_then(|mut active| active.take());
    let Some(active) = active else {
        return;
    };
    if let Some(popup) = app.get_webview_window("filter-popup") {
        let _ = crate::windows::dismiss(&popup, crate::windows::Role::OwnedPopup);
        let _ = popup.emit("filter-opened", Option::<Request>::None);
    }
    if restore {
        crate::windows::focus_owner(app, &active.owner);
    }
    let mut payload = serde_json::json!({"session": active.request.session, "restore": restore});
    if let Some(value) = value {
        payload["value"] = value.into();
    }
    let _ = app.emit_to(&active.owner, "filter-closed", payload);
}
pub fn belongs_to(app: &tauri::AppHandle, owner: &str) -> bool {
    app.state::<FilterPopup>()
        .0
        .lock()
        .ok()
        .and_then(|active| active.as_ref().map(|active| active.owner == owner))
        .unwrap_or(false)
}
pub fn handle_event(window: &tauri::Window, event: &WindowEvent) {
    if window.label() == "filter-popup" {
        match event {
            WindowEvent::Focused(false) => dismiss(window.app_handle(), None, false),
            WindowEvent::CloseRequested { api, .. } => {
                api.prevent_close();
                dismiss(window.app_handle(), None, false);
            }
            _ => {}
        }
    } else if matches!(
        event,
        WindowEvent::Moved(_)
            | WindowEvent::Resized(_)
            | WindowEvent::CloseRequested { .. }
            | WindowEvent::Destroyed
    ) && belongs_to(window.app_handle(), window.label())
    {
        dismiss(window.app_handle(), None, false);
    }
}

#[tauri::command]
pub fn forward_filter_shortcut(
    app: tauri::AppHandle,
    session: String,
    key: String,
    meta: bool,
    ctrl: bool,
) {
    if !(meta || ctrl) || !matches!(key.as_str(), "Escape" | "," | "k") {
        return;
    }
    let owner = app.state::<FilterPopup>().0.lock().ok().and_then(|active| {
        active
            .as_ref()
            .filter(|active| active.request.session == session)
            .map(|active| active.owner.clone())
    });
    if let Some(owner) = owner {
        let _ = app.emit_to(
            owner,
            "filter-shortcut",
            serde_json::json!({"session": session, "key": key, "meta": meta, "ctrl": ctrl}),
        );
        dismiss(&app, None, false);
    }
}

#[tauri::command]
pub fn size_filter_popup(
    app: tauri::AppHandle,
    session: String,
    height: f64,
) -> Result<(), String> {
    if !height.is_finite() || !(40.0..=252.0).contains(&height) {
        return Err("Invalid popup height".into());
    }
    let active = app
        .state::<FilterPopup>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .as_ref()
        .filter(|active| active.request.session == session)
        .map(|active| (active.owner.clone(), active.request.clone()));
    let Some((owner, request)) = active else {
        return Ok(());
    };
    let window = app
        .get_webview_window(&owner)
        .ok_or("Filter owner is unavailable")?;
    let popup = app
        .get_webview_window("filter-popup")
        .ok_or("Filter window is unavailable")?;
    let visible = popup.is_visible().map_err(|e| e.to_string())?;
    popup
        .set_size(tauri::LogicalSize::new(202.0, height))
        .map_err(|e| e.to_string())?;
    let origin = window.inner_position().map_err(|e| e.to_string())?;
    let scale = window.scale_factor().map_err(|e| e.to_string())?;

    let monitor = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .ok_or("Display is unavailable")?;
    let area = monitor.work_area();
    let width = 202.0 * scale;
    let height = height * scale;
    let top = origin.y as f64 + request.anchor.y * scale;
    let (x, y) = crate::popup_position::below(
        origin.x as f64 + request.anchor.x * scale - width,
        top,
        top + request.anchor.height * scale,
        width,
        height,
        area.position.x as f64,
        area.position.y as f64,
        area.size.width as f64,
        area.size.height as f64,
        4. * scale,
    );
    popup
        .set_position(PhysicalPosition::new(x as i32, y as i32))
        .map_err(|e| e.to_string())?;

    if !visible {
        crate::windows::present(&popup, crate::windows::Role::OwnedPopup).map_err(|e| e.to_string())?;
    }
    Ok(())
}
