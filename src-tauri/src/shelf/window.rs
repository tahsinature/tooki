use tauri::Manager;
/// Floating shelves own their window geometry, independently of the launcher.
pub fn show(app: &tauri::AppHandle, id: &str, title: &str) -> Result<(), String> {
    show_with_focus(app, id, title, true)
}
pub fn show_with_focus(
    app: &tauri::AppHandle,
    id: &str,
    title: &str,
    focus: bool,
) -> Result<(), String> {
    let label = format!("shelf-{id}");
    if let Some(window) = app.get_webview_window(&label) {
        window.show().map_err(|e| e.to_string())?;
        return if focus {
            window.set_focus().map_err(|e| e.to_string())
        } else {
            Ok(())
        };
    }
    let builder = tauri::WebviewWindowBuilder::new(
        app,
        &label,
        tauri::WebviewUrl::App(format!("index.html?window=shelf&shelf={id}").into()),
    )
    // A drop must never navigate the application webview to the dropped file.
    .on_navigation(|url| {
        matches!(url.scheme(), "tauri" | "http" | "https")
            && matches!(
                url.host_str(),
                Some("localhost" | "tauri.localhost" | "127.0.0.1")
            )
    })
    .title(title)
    .visible(false)
    .focused(focus)
    .accept_first_mouse(true)
    .inner_size(300., 160.)
    .resizable(false)
    .decorations(false)
    .transparent(true)
    .always_on_top(!focus)
    .skip_taskbar(true);
    let window = builder.build().map_err(|e| e.to_string())?;
    crate::platform::window_chrome::apply(&window)?;
    super::positions::restore(&window, id)?;
    window.show().map_err(|e| e.to_string())?;
    if focus {
        window.set_focus().map_err(|e| e.to_string())?;
    }
    Ok(())
}
