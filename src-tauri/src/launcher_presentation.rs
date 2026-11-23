use serde::Serialize;
use std::{sync::Mutex, time::SystemTime};
use tauri::{Emitter, Manager};

#[derive(Default)]
pub struct Presentation(Mutex<Requests>);
#[derive(Clone, Copy, Default, Serialize, PartialEq, Debug)]
#[serde(rename_all = "camelCase")]
enum EntryMode {
    Resume,
    #[default]
    Fresh,
}
#[derive(Clone, Serialize)]
pub struct Entry {
    mode: EntryMode,
    target: Option<String>,
}
#[derive(Default)]
struct Requests {
    revision: u64,
    pending: Option<u64>,
    target: Option<String>,
    mode: EntryMode,
    active_view: String,
    session: crate::launcher_session::Session,
}
impl Requests {
    fn begin(&mut self, mode: EntryMode, target: Option<String>) -> u64 {
        self.mode = mode;
        self.target = target;
        self.revision += 1;
        self.pending = Some(self.revision);
        self.revision
    }
    fn entry(&self, revision: u64) -> Option<Entry> {
        (self.pending == Some(revision)).then(|| Entry {
            mode: self.mode,
            target: self.target.clone(),
        })
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
/// Return from any Tooki window without toggling or closing the launcher.
#[tauri::command]
pub async fn return_to_root_search(app: tauri::AppHandle) -> Result<(), String> {
    crate::snippets::cancel_pending(&app).await?;
    crate::filter_popup::dismiss(&app, None, false);
    crate::app_menu::dismiss(&app);
    crate::platform::preview::close_window(&app, "main");
    request(&app).map_err(|error| error.to_string())
}
pub fn dismiss(app: &tauri::AppHandle) -> tauri::Result<()> {
    cancel(app);
    if let Some(window) = app.get_webview_window("main") {
        crate::launcher_placement::remember(app);
        crate::windows::dismiss(&window, crate::windows::Role::Launcher)?;
        app.state::<Presentation>()
            .0
            .lock()
            .unwrap()
            .session
            .dismissed(SystemTime::now());
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
/// Explicit root entry (startup, menu action, or Command-Escape).
pub fn request(app: &tauri::AppHandle) -> tauri::Result<()> {
    prepare(app, EntryMode::Fresh, None)
}
/// The launcher shortcut resumes the existing frontend and its navigation state.
pub fn resume(app: &tauri::AppHandle) -> tauri::Result<()> {
    let minutes = crate::general_settings::launcher_session_minutes(app);
    let mode = if app
        .state::<Presentation>()
        .0
        .lock()
        .unwrap()
        .session
        .can_resume(minutes, SystemTime::now())
    {
        EntryMode::Resume
    } else {
        EntryMode::Fresh
    };
    prepare(app, mode, None)
}
pub fn request_tool(app: &tauri::AppHandle, id: &str) -> tauri::Result<()> {
    prepare(app, EntryMode::Fresh, Some(id.into()))
}
fn prepare(app: &tauri::AppHandle, mode: EntryMode, target: Option<String>) -> tauri::Result<()> {
    let revision = app
        .state::<Presentation>()
        .0
        .lock()
        .unwrap()
        .begin(mode, target);
    if let Err(error) = app.emit_to("main", "launcher-prepare", revision) {
        cancel(app);
        return Err(error);
    }
    Ok(())
}
#[tauri::command]
pub fn launcher_request_entry(app: tauri::AppHandle, revision: u64) -> Option<Entry> {
    app.state::<Presentation>()
        .0
        .lock()
        .unwrap()
        .entry(revision)
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
        let completed = handle
            .state::<Presentation>()
            .0
            .lock()
            .unwrap()
            .complete(revision);
        if completed {
            if let Err(error) = crate::windows::present(&window, crate::windows::Role::Launcher) {
                eprintln!("Could not present launcher: {error}");
            } else {
                handle
                    .state::<Presentation>()
                    .0
                    .lock()
                    .unwrap()
                    .session
                    .presented();
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
    fn resume_fresh_root_and_fresh_tool_are_distinct_and_cancelled_requests_are_ignored() {
        let mut requests = Requests::default();
        let resume = requests.begin(EntryMode::Resume, None);
        assert_eq!(requests.entry(resume).unwrap().mode, EntryMode::Resume);
        let tool = requests.begin(EntryMode::Fresh, Some("command:clipboard.open".into()));
        assert!(requests.entry(resume).is_none());
        let entry = requests.entry(tool).unwrap();
        assert_eq!(entry.mode, EntryMode::Fresh);
        assert_eq!(entry.target.as_deref(), Some("command:clipboard.open"));
        assert!(requests.cancel());
        assert!(requests.entry(tool).is_none());
        let root = requests.begin(EntryMode::Fresh, None);
        let entry = requests.entry(root).unwrap();
        assert_eq!(entry.mode, EntryMode::Fresh);
        assert!(entry.target.is_none());
    }
    #[test]
    fn repeated_tool_shortcut_cancels_only_its_pending_open() {
        let mut requests = Requests::default();
        let revision = requests.begin(EntryMode::Fresh, Some("command:shelf.open".into()));
        assert!(!requests.cancel_tool("command:clipboard.open"));
        assert!(requests.cancel_tool("command:shelf.open"));
        assert!(!requests.complete(revision));
        assert!(!requests.cancel_tool("command:shelf.open"));
        let root = requests.begin(EntryMode::Fresh, None);
        assert!(!requests.cancel_tool("command:shelf.open"));
        assert!(requests.complete(root));
    }
    #[test]
    fn a_cancelled_or_superseded_preparation_cannot_reopen_the_launcher() {
        let mut requests = Requests::default();
        let first = requests.begin(EntryMode::Fresh, None);
        assert!(requests.cancel());
        assert!(!requests.complete(first));
        let second = requests.begin(EntryMode::Fresh, None);
        let third = requests.begin(EntryMode::Fresh, None);
        assert!(!requests.complete(second));
        assert!(requests.complete(third));
        assert!(!requests.complete(third));
        assert!(!requests.cancel());
    }
}
