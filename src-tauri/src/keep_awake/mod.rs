mod model;
mod native;
mod preferences;
#[cfg(test)]
mod tests;
mod tray;

use model::{Controller, Mode};
use native::Assertion;
use serde::Serialize;
use std::{
    sync::Mutex,
    time::{Duration, SystemTime},
};
use tauri::Manager;

#[derive(Default)]
pub struct KeepAwake(
    Mutex<Controller<Assertion>>,
    Mutex<preferences::Preferences>,
);

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    supported: bool,
    show_menu_bar_icon: bool,
    active: bool,
    mode: Mode,
    remaining_seconds: Option<u64>,
    duration_minutes: Option<u32>,
}

fn refresh(value: &mut Controller<Assertion>) {
    value.expire(SystemTime::now());
    if value
        .session
        .as_ref()
        .is_some_and(|session| !session.assertion.active())
    {
        value.stop();
    }
}

#[tauri::command]
pub fn keep_awake_status(app: tauri::AppHandle) -> Result<Status, String> {
    let state = app.state::<KeepAwake>();
    let mut value = state.0.lock().map_err(|e| e.to_string())?;
    refresh(&mut value);
    let show_menu_bar_icon = state
        .1
        .lock()
        .map_err(|e| e.to_string())?
        .show_menu_bar_icon;
    Ok(Status {
        show_menu_bar_icon,
        supported: cfg!(target_os = "macos"),
        active: value.session.is_some(),
        mode: value.mode,
        duration_minutes: value
            .session
            .as_ref()
            .and_then(|session| session.duration_minutes),
        remaining_seconds: value
            .session
            .as_ref()
            .and_then(|session| session.deadline)
            .map(|deadline| {
                deadline
                    .duration_since(SystemTime::now())
                    .unwrap_or_default()
                    .as_secs_f64()
                    .ceil() as u64
            }),
    })
}

#[tauri::command]
pub fn set_keep_awake_mode(app: tauri::AppHandle, mode: Mode) -> Result<(), String> {
    crate::system_actions::require("power.keepAwake")?;
    let state = app.state::<KeepAwake>();
    let mut value = state.0.lock().map_err(|e| e.to_string())?;
    refresh(&mut value);
    value.set_mode(mode, SystemTime::now(), Assertion::acquire)
}

pub fn execute(app: &tauri::AppHandle, id: &str) -> Result<(), String> {
    crate::system_actions::require("power.keepAwake")?;
    let state = app.state::<KeepAwake>();
    let mut value = state.0.lock().map_err(|e| e.to_string())?;
    refresh(&mut value);
    let minutes = match id {
        "command:system.keepAwake15" => Some(15),
        "command:system.keepAwake60" => Some(60),
        "command:system.keepAwake120" => Some(120),
        "command:system.keepAwakeOn" => None,
        "command:system.keepAwakeOff" => {
            value.stop();
            return Ok(());
        }
        "command:system.keepAwakeToggle" if value.session.is_some() => {
            value.stop();
            return Ok(());
        }
        "command:system.keepAwakeToggle" => None,
        _ => return Err("Unknown Keep Awake command.".into()),
    };
    value.start(minutes, SystemTime::now(), Assertion::acquire)
}

#[tauri::command]
pub fn set_keep_awake_icon(app: tauri::AppHandle, visible: bool) -> Result<(), String> {
    crate::system_actions::require("power.keepAwake")?;
    let state = app.state::<KeepAwake>();
    let mut current = state.1.lock().map_err(|e| e.to_string())?;
    let next = preferences::Preferences {
        show_menu_bar_icon: visible,
    };
    preferences::save(&app, &next)?;
    *current = next;
    drop(current);
    tray::sync(&app);
    Ok(())
}

pub fn reload_preferences(app: &tauri::AppHandle) -> Result<(), String> {
    *app.state::<KeepAwake>().1.lock().unwrap() = crate::config::read(app, "keepAwake")?;
    tray::sync(app);
    Ok(())
}

pub fn initialize(app: &tauri::AppHandle) {
    match preferences::load(app) {
        Ok(preferences) => *app.state::<KeepAwake>().1.lock().unwrap() = preferences,
        Err(error) => eprintln!("Keep Awake settings: {error}"),
    }
    let app = app.clone();
    tauri::async_runtime::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(1)).await;
            let state = app.state::<KeepAwake>();
            let Ok(mut value) = state.0.lock() else { break };
            if value.shutdown {
                break;
            }
            // IOKit also owns the timeout, so expiry does not depend on the UI or this task.
            refresh(&mut value);
            drop(value);
            tray::sync(&app);
        }
    });
}

pub fn stop(app: &tauri::AppHandle) {
    let state = app.state::<KeepAwake>();
    if let Ok(mut value) = state.0.lock() {
        value.shutdown();
    };
}

pub fn validate_configuration(config: &crate::config::Config) -> Result<(), String> {
    config
        .read::<preferences::Preferences>("settings.json", "keepAwake", Default::default())
        .map(|_| ())
}
