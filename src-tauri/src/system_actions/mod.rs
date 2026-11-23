mod confirmation;
pub mod platform;
use serde::{Deserialize, Serialize};
use std::{sync::Mutex, time::Instant};
use tauri::Manager;

#[derive(Default)]
pub struct SystemActions(Mutex<()>, Mutex<confirmation::Confirmation>);
#[derive(Serialize, Deserialize)]
pub struct Volume {
    pub id: String,
    pub name: String,
    pub path: String,
}

pub fn require(capability: &str) -> Result<(), String> {
    if platform::supports(capability, std::env::consts::OS) {
        Ok(())
    } else {
        Err("This action is not supported on this platform yet.".into())
    }
}

pub async fn execute(app: tauri::AppHandle, id: String) -> Result<(), String> {
    let capability = match id.as_str() {
        "command:system.sleep" => "power.sleep",
        "command:system.emptyTrash" => "trash.empty",
        _ => return Err("Unknown system action.".into()),
    };
    require(capability)?;
    if id == "command:system.emptyTrash" {
        let state = app.state::<SystemActions>();
        let _guard = state
            .0
            .try_lock()
            .map_err(|_| "Another system action is already running.")?;
        let request = state
            .1
            .lock()
            .map_err(|e| e.to_string())?
            .begin(Instant::now());
        if let Err(error) = crate::launcher_presentation::request_tool(&app, &id) {
            state
                .1
                .lock()
                .map_err(|e| e.to_string())?
                .consume(request, Instant::now());
            return Err(error.to_string());
        }
        return Ok(());
    }
    let worker = app.clone();
    let result = tauri::async_runtime::spawn_blocking(move || {
        let state = worker.state::<SystemActions>();
        let _guard = state
            .0
            .try_lock()
            .map_err(|_| "Another system action is already running.")?;
        platform::sleep()
    })
    .await
    .map_err(|e| e.to_string())
    .and_then(|result| result);
    crate::command_feedback::finish(&app, result, "Sleep requested")
}

#[tauri::command]
pub fn pending_empty_trash(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<Option<u64>, String> {
    if window.label() != "main" {
        return Err("Confirmation belongs to the launcher.".into());
    }
    Ok(app
        .state::<SystemActions>()
        .1
        .lock()
        .map_err(|e| e.to_string())?
        .current(Instant::now()))
}

#[tauri::command]
pub async fn confirm_empty_trash(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    request: u64,
    confirmed: bool,
) -> Result<(), String> {
    require("trash.empty")?;
    if window.label() != "main" {
        return Err("Confirmation belongs to the launcher.".into());
    }
    let accepted = app
        .state::<SystemActions>()
        .1
        .lock()
        .map_err(|e| e.to_string())?
        .consume(request, Instant::now());
    if !confirmed {
        return Ok(());
    }
    if !accepted {
        return Err("This confirmation expired. Choose Empty Trash again.".into());
    }
    let worker = app.clone();
    let result = tauri::async_runtime::spawn_blocking(move || {
        let state = worker.state::<SystemActions>();
        let _guard = state
            .0
            .try_lock()
            .map_err(|_| "Another system action is already running.")?;
        platform::empty_trash()
    })
    .await
    .map_err(|e| e.to_string())
    .and_then(|result| result);
    crate::command_feedback::finish(&app, result, "Trash emptied")
}

#[tauri::command]
pub async fn system_volumes() -> Result<Vec<Volume>, String> {
    require("storage.eject")?;
    tauri::async_runtime::spawn_blocking(platform::volumes)
        .await
        .map_err(|e| e.to_string())?
}
#[tauri::command]
pub async fn eject_system_volume(app: tauri::AppHandle, id: String) -> Result<(), String> {
    require("storage.eject")?;
    let worker = app.clone();
    let result = tauri::async_runtime::spawn_blocking(move || {
        let state = worker.state::<SystemActions>();
        let _guard = state
            .0
            .try_lock()
            .map_err(|_| "Another system action is already running.")?;
        platform::eject(&id)
    })
    .await
    .map_err(|e| e.to_string())
    .and_then(|result| result);
    crate::command_feedback::finish(&app, result, "Disk ejected")
}
#[tauri::command]
pub fn open_automation_settings() -> Result<(), String> {
    require("trash.empty")?;
    #[cfg(target_os = "macos")]
    std::process::Command::new("/usr/bin/open")
        .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}
