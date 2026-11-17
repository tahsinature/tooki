//! Shelferry owns all shelf data and windows. Only its public CLI is used here.
mod cli;
use serde::{Deserialize, Serialize};
use std::{path::PathBuf, sync::Mutex};
use tauri::{Emitter, Manager};

#[derive(Clone, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Preferences {
    pub enabled: bool,
    pub executable: String,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            enabled: true,
            executable: String::new(),
        }
    }
}
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub preferences: Preferences,
    pub executable: Option<PathBuf>,
    pub available: bool,
    pub reason: Option<String>,
    pub install_command: &'static str,
}
#[derive(Default)]
pub struct Shelferry {
    preferences: Mutex<Preferences>,
    platform_reason: Mutex<Option<String>>,
    configuration_error: Mutex<Option<String>>,
    queue: tokio::sync::Mutex<()>,
}
fn candidates() -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = [
        "/opt/homebrew/bin/shelferry",
        "/usr/local/bin/shelferry",
        "/Applications/Shelferry.app/Contents/Helpers/shelferry",
    ]
    .into_iter()
    .map(PathBuf::from)
    .collect();
    if let Some(home) = std::env::var_os("HOME") {
        paths.push(
            PathBuf::from(home).join("Applications/Shelferry.app/Contents/Helpers/shelferry"),
        );
    }
    if let Some(path) = std::env::var_os("PATH") {
        paths.extend(std::env::split_paths(&path).map(|directory| directory.join("shelferry")));
    }
    paths
}
pub fn status(app: &tauri::AppHandle) -> Status {
    let state = app.state::<Shelferry>();
    let preferences = state.preferences.lock().unwrap().clone();
    let result = if let Some(reason) = state.platform_reason.lock().unwrap().clone() {
        Err(reason)
    } else if let Some(error) = state.configuration_error.lock().unwrap().clone() {
        Err(error)
    } else if !preferences.enabled {
        Err("Shelferry extension is disabled. Enable it in Settings → Shelferry.".into())
    } else {
        cli::discover(&preferences.executable, candidates())
    };
    Status {
        preferences,
        available: result.is_ok(),
        executable: result.as_ref().ok().cloned(),
        reason: result.err(),
        install_command: cli::INSTALL,
    }
}
pub fn initialize(app: &tauri::AppHandle) {
    let state = app.state::<Shelferry>();
    #[cfg(target_os = "macos")]
    let major = Some(unsafe {
        unsafe extern "C" {
            fn tooki_macos_major_version() -> u32;
        }
        tooki_macos_major_version()
    });
    #[cfg(not(target_os = "macos"))]
    let major = None;
    *state.platform_reason.lock().unwrap() = cli::platform_reason(std::env::consts::OS, major);
    let load = || -> Result<Preferences, String> {
        let path = app
            .path()
            .app_config_dir()
            .map_err(|e| e.to_string())?
            .join("shelferry-extension.json");
        match std::fs::read(path) {
            Ok(bytes) => serde_json::from_slice(&bytes)
                .map_err(|e| format!("Cannot read Shelferry integration preferences: {e}")),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Preferences::default()),
            Err(e) => Err(e.to_string()),
        }
    };
    match load() {
        Ok(preferences) => *state.preferences.lock().unwrap() = preferences,
        Err(error) => *state.configuration_error.lock().unwrap() = Some(error),
    }
    crate::shelf::initialize_legacy_links(app);
}
#[tauri::command]
pub async fn shelferry_status(app: tauri::AppHandle) -> Result<Status, String> {
    tauri::async_runtime::spawn_blocking(move || status(&app))
        .await
        .map_err(|e| e.to_string())
}
#[tauri::command]
pub async fn configure_shelferry(
    app: tauri::AppHandle,
    mut preferences: Preferences,
) -> Result<Status, String> {
    let state = app.state::<Shelferry>();
    let _guard = state.queue.lock().await;
    preferences.executable = preferences.executable.trim().into();
    // An invalid explicit override is saved and reported, never silently replaced.
    let handle = app.clone();
    let next = preferences.clone();
    tauri::async_runtime::spawn_blocking(move || -> Result<(), String> {
        let directory = handle.path().app_config_dir().map_err(|e| e.to_string())?;
        std::fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
        let temporary = directory.join("shelferry-extension.tmp");
        std::fs::write(
            &temporary,
            serde_json::to_vec_pretty(&next).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        std::fs::rename(temporary, directory.join("shelferry-extension.json"))
            .map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())??;
    *state.preferences.lock().unwrap() = preferences;
    *state.configuration_error.lock().unwrap() = None;
    refresh(&app);
    Ok(status(&app))
}
fn refresh(app: &tauri::AppHandle) {
    crate::applications::preferences::sync_tool_shortcuts(app, "shelf", status(app).available);
    let _ = app.emit("command-support-changed", ());
}
#[tauri::command]
pub async fn check_shelferry(app: tauri::AppHandle) -> Result<Status, String> {
    let state = app.state::<Shelferry>();
    let _guard = state.queue.lock().await;
    refresh(&app);
    let status = status(&app);
    if let Some(path) = &status.executable {
        cli::run(path, "ping").await?;
    }
    Ok(status)
}
pub async fn execute(app: &tauri::AppHandle, id: &str) -> Result<(), String> {
    let operation = cli::operation(id).ok_or("Unknown Shelferry command")?;
    let state = app.state::<Shelferry>();
    // Toggle requests must execute in order, with no retries after ambiguous failures.
    let _guard = state.queue.lock().await;
    let current = status(app);
    let path = current
        .executable
        .ok_or_else(|| current.reason.unwrap_or_default())?;
    cli::run(&path, operation).await?;
    crate::launcher_presentation::dismiss_launcher(app.clone())
}
