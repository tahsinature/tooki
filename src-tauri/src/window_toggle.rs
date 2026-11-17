//! Shared focus policy for shortcut-controlled tool windows.
use tauri::{AppHandle, Manager, WebviewWindow};

fn hide_active_view(same_view: bool, visible: bool, minimized: bool, focused: bool) -> bool {
    same_view && visible && !minimized && focused
}

pub fn should_hide(
    app: &AppHandle,
    window: &WebviewWindow,
    same_view: bool,
) -> tauri::Result<bool> {
    let label = window.label();
    let popup_focused = crate::filter_popup::belongs_to(app, label)
        || (label == "main"
            && app
                .get_webview_window("app-menu")
                .is_some_and(|menu| menu.is_visible().unwrap_or(false)));
    Ok(hide_active_view(
        same_view,
        window.is_visible()?,
        window.is_minimized()?,
        window.is_focused()? || popup_focused,
    ))
}

pub fn dismiss_popups(app: &AppHandle, label: &str) {
    if crate::filter_popup::belongs_to(app, label) {
        crate::filter_popup::dismiss(app, None, false);
    }
    if label == "main" {
        crate::app_menu::dismiss(app);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_the_active_visible_tool_hides() {
        assert!(hide_active_view(true, true, false, true));
        assert!(
            !hide_active_view(false, true, false, true),
            "switch tools in the shared window"
        );
        assert!(
            !hide_active_view(true, false, false, true),
            "show hidden tools"
        );
        assert!(
            !hide_active_view(true, true, true, true),
            "restore minimized tools"
        );
        assert!(
            !hide_active_view(true, true, false, false),
            "focus background tools"
        );
    }
}
