mod native;
mod session;
pub use native::{open_settings, required};
use serde::Serialize;
use session::Session;
use std::sync::Mutex;
use tauri::{Emitter, Manager};

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    supported: bool,
    granted: bool,
    prompt: bool,
    build: &'static str,
    app_path: String,
}

fn snapshot(app: &tauri::AppHandle) -> Status {
    let state = app.state::<Mutex<Session>>();
    let state = state.lock().unwrap();
    let executable = std::env::current_exe().unwrap_or_default();
    let bundle = executable
        .ancestors()
        .find(|p| p.extension().is_some_and(|v| v == "app"));
    Status {
        supported: cfg!(target_os = "macos"),
        granted: state.granted,
        prompt: state.prompt,
        build: if cfg!(debug_assertions) {
            "Development"
        } else {
            "Production"
        },
        app_path: bundle.unwrap_or(&executable).to_string_lossy().into_owned(),
    }
}

// All state transitions and native hook recovery run on the AppKit thread.
fn refresh(app: &tauri::AppHandle) {
    let granted = !required();
    let changed = app
        .state::<Mutex<Session>>()
        .lock()
        .unwrap()
        .observe(granted);
    if !changed {
        return;
    }
    crate::hyper::permission_changed(app);
    if granted {
        crate::platform::root_search_shortcut::initialize(app);
    }
    let handle = app.clone();
    tauri::async_runtime::spawn(async move {
        if let Err(error) = crate::snippets::configure(&handle).await {
            eprintln!("Could not refresh snippet permissions: {error}");
        }
        let _ = handle.emit("snippets-changed", ());
    });
    let _ = app.emit("permissions-changed", snapshot(app));
    present_if_needed(app);
}

fn present_if_needed(app: &tauri::AppHandle) {
    let should_present = {
        let state = app.state::<Mutex<Session>>();
        let state = state.lock().unwrap();
        state.ready && state.prompt
    };
    if should_present {
        if let Err(error) = crate::settings_window::open_settings(app.clone(), None) {
            eprintln!("Could not show Accessibility setup: {error}");
        }
    }
}

pub fn initialize(app: &tauri::AppHandle) {
    app.manage(Mutex::new(Session::new(!required())));
    if !cfg!(target_os = "macos") {
        return;
    }
    let app = app.clone();
    tauri::async_runtime::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            let handle = app.clone();
            if app.run_on_main_thread(move || refresh(&handle)).is_err() {
                break;
            }
        }
    });
}

pub fn require_accessibility(app: &tauri::AppHandle) -> Result<(), String> {
    if !required() {
        return Ok(());
    }
    let handle = app.clone();
    app.run_on_main_thread(move || {
        refresh(&handle);
        handle.state::<Mutex<Session>>().lock().unwrap().prompt = true;
        let _ = handle.emit("permissions-changed", snapshot(&handle));
        present_if_needed(&handle);
    })
    .map_err(|e| e.to_string())?;
    Err("Enable Accessibility for this copy of Tooki. Copy still works while permission is missing.".into())
}

pub async fn request(app: &tauri::AppHandle, operation: &str) -> Result<Status, String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    let handle = app.clone();
    let operation = operation.to_owned();
    app.run_on_main_thread(move || {
        let result = (|| {
            refresh(&handle);
            match operation.as_str() {
                "ready" => handle.state::<Mutex<Session>>().lock().unwrap().ready = true,
                "dismiss" => handle.state::<Mutex<Session>>().lock().unwrap().prompt = false,
                "show" => handle.state::<Mutex<Session>>().lock().unwrap().prompt = required(),
                "open" => open_settings()?,
                "status" => {}
                _ => return Err("Unknown permission operation.".to_string()),
            }
            if matches!(operation.as_str(), "ready" | "show") {
                present_if_needed(&handle);
            }
            let status = snapshot(&handle);
            let _ = handle.emit("permissions-changed", status.clone());
            Ok(status)
        })();
        let _ = tx.send(result);
    })
    .map_err(|e| e.to_string())?;
    rx.await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn permission_request(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    operation: String,
) -> Result<Status, String> {
    if window.label() != "settings" {
        return Err("Manage permissions in Tooki Settings.".into());
    }
    request(&app, &operation).await
}
