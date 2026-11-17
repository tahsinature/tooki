use std::sync::Mutex;
use tauri::{Emitter, Manager};

#[derive(Default)]
pub struct Presentation(Mutex<Requests>);
#[derive(Default)]
struct Requests {
    revision: u64,
    pending: Option<u64>,
    target: Option<String>,
    active_view: String,
}
impl Requests {
    fn begin(&mut self) -> u64 {
        self.target = None;
        self.revision += 1;
        self.pending = Some(self.revision);
        self.revision
    }
    fn cancel(&mut self) -> bool {
        self.pending.take().is_some()
    }
    fn cancel_tool(&mut self, id: &str) -> bool {
        self.target.as_deref() == Some(id) && self.cancel()
    }
    fn complete(&mut self, revision: u64) -> bool {
        if self.pending != Some(revision) {
            return false;
        }
        self.pending = None;
        true
    }
}
pub fn cancel(app: &tauri::AppHandle) -> bool {
    app.state::<Presentation>().0.lock().unwrap().cancel()
}
/// One dismissal path for completed actions, Escape, and launcher shortcuts.
#[tauri::command]
pub fn dismiss_launcher(app: tauri::AppHandle) -> Result<(), String> {
    dismiss(&app).map_err(|error| error.to_string())
}
pub fn dismiss(app: &tauri::AppHandle) -> tauri::Result<()> {
    cancel(app);
    crate::window_toggle::dismiss_popups(app, "main");
    crate::platform::preview::close_window(app, "main");
    if let Some(window) = app.get_webview_window("main") {
        crate::platform::launcher::dismiss(&window)?;
    }
    Ok(())
}
/// The frontend reports navigation too, not only views opened by shortcuts.
#[tauri::command]
pub fn set_launcher_view(app: tauri::AppHandle, window: tauri::WebviewWindow, view: String) {
    if window.label() == "main"
        && matches!(
            view.as_str(),
            "root" | "systemMonitor" | "clipboard" | "system" | "keepAwake" | "snippets" | "emoji"
        )
    {
        app.state::<Presentation>().0.lock().unwrap().active_view = view;
    }
}
pub fn active_view(app: &tauri::AppHandle) -> String {
    app.state::<Presentation>()
        .0
        .lock()
        .unwrap()
        .active_view
        .clone()
}
pub fn cancel_tool(app: &tauri::AppHandle, id: &str) -> bool {
    let state = app.state::<Presentation>();
    let mut requests = state.0.lock().unwrap();
    requests.cancel_tool(id)
}
pub fn request(app: &tauri::AppHandle) -> tauri::Result<()> {
    let revision = app.state::<Presentation>().0.lock().unwrap().begin();
    if let Err(error) = app.emit_to("main", "launcher-prepare", revision) {
        cancel(app);
        return Err(error);
    }
    Ok(())
}
pub fn request_tool(app: &tauri::AppHandle, id: &str) -> tauri::Result<()> {
    let revision = {
        let state = app.state::<Presentation>();
        let mut requests = state.0.lock().unwrap();
        let revision = requests.begin();
        requests.target = Some(id.into());
        revision
    };
    if let Err(error) = app.emit_to("main", "launcher-prepare", revision) {
        cancel(app);
        return Err(error);
    }
    Ok(())
}
#[tauri::command]
pub fn launcher_request_target(app: tauri::AppHandle, revision: u64) -> Option<String> {
    let state = app.state::<Presentation>();
    let requests = state.0.lock().unwrap();
    if requests.pending == Some(revision) {
        requests.target.clone()
    } else {
        None
    }
}
#[tauri::command]
pub fn launcher_frontend_ready(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> tauri::Result<()> {
    if window.label() != "main" {
        return Ok(());
    }
    let pending = app.state::<Presentation>().0.lock().unwrap().pending;
    if let Some(revision) = pending {
        window.emit("launcher-prepare", revision)?;
    }
    Ok(())
}
#[tauri::command]
pub fn present_prepared_launcher(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    revision: u64,
) -> tauri::Result<()> {
    if window.label() != "main" {
        return Ok(());
    }
    let handle = app.clone();
    app.run_on_main_thread(move || {
        if handle
            .state::<Presentation>()
            .0
            .lock()
            .unwrap()
            .complete(revision)
        {
            if let Err(error) = crate::platform::launcher::present(&window) {
                eprintln!("Could not present launcher: {error}");
            }
        }
    })
}
#[tauri::command]
pub fn cancel_launcher_preparation(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    revision: u64,
) {
    if window.label() == "main" {
        app.state::<Presentation>()
            .0
            .lock()
            .unwrap()
            .complete(revision);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn repeated_tool_shortcut_cancels_only_its_pending_open() {
        let mut requests = Requests::default();
        let revision = requests.begin();
        requests.target = Some("command:shelf.open".into());
        assert!(!requests.cancel_tool("command:clipboard.open"));
        assert!(requests.cancel_tool("command:shelf.open"));
        assert!(!requests.complete(revision));
        assert!(!requests.cancel_tool("command:shelf.open"));
        let root = requests.begin();
        assert!(!requests.cancel_tool("command:shelf.open"));
        assert!(requests.complete(root));
    }
    #[test]
    fn a_cancelled_or_superseded_preparation_cannot_reopen_the_launcher() {
        let mut requests = Requests::default();
        let first = requests.begin();
        assert!(requests.cancel());
        assert!(!requests.complete(first));
        let second = requests.begin();
        let third = requests.begin();
        assert!(!requests.complete(second));
        assert!(requests.complete(third));
        assert!(!requests.complete(third));
        assert!(!requests.cancel());
    }
}
