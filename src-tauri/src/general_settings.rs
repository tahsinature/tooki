use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager,
};
use tauri_plugin_autostart::ManagerExt;

const TRAY_ID: &str = "tooki";
#[derive(Clone, Serialize, Deserialize)]
struct Preferences {
    show_tray: bool,
    #[serde(default = "default_session_minutes")]
    launcher_session_minutes: Option<u32>,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            show_tray: true,
            launcher_session_minutes: default_session_minutes(),
        }
    }
}
fn default_session_minutes() -> Option<u32> {
    Some(5)
}
fn validate_session_minutes(minutes: Option<u32>) -> Result<(), String> {
    if minutes.is_some_and(|value| value > 10080) {
        return Err("Choose a whole number from 1 to 10080 minutes, Never, or Always.".into());
    }
    Ok(())
}
#[derive(Default)]
pub struct GeneralSettings(Mutex<Preferences>);
#[derive(Serialize)]
pub struct Status {
    launch_at_login: bool,
    show_tray: bool,
    launcher_session_minutes: Option<u32>,
}

fn save(app: &tauri::AppHandle, value: &Preferences) -> Result<(), String> {
    crate::config::save(app, "general", value)
}
fn set_tray(app: &tauri::AppHandle, visible: bool) -> Result<(), String> {
    if !visible {
        app.remove_tray_by_id(TRAY_ID);
        return Ok(());
    }
    if app.tray_by_id(TRAY_ID).is_some() {
        return Ok(());
    }
    let open = MenuItem::with_id(app, "open", "Open Tooki", true, None::<&str>)
        .map_err(|e| e.to_string())?;
    let settings = MenuItem::with_id(app, "settings", "Settings…", true, None::<&str>)
        .map_err(|e| e.to_string())?;
    let quit = MenuItem::with_id(app, "quit", "Quit Tooki", true, None::<&str>)
        .map_err(|e| e.to_string())?;
    let menu = Menu::with_items(app, &[&open, &settings, &quit]).map_err(|e| e.to_string())?;
    let icon = app
        .default_window_icon()
        .ok_or("Application icon is unavailable")?
        .clone();
    let tray = TrayIconBuilder::with_id(TRAY_ID)
        .icon(icon)
        .tooltip(if cfg!(debug_assertions) {
            "Tooki Dev"
        } else {
            "Tooki"
        })
        .menu(&menu)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open" => {
                if app.get_webview_window("main").is_some() {
                    let _ = crate::launcher_presentation::request(app);
                }
            }
            "settings" => {
                let _ = crate::settings_window::open_settings(app.clone(), Some("general".into()));
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .build(app)
        .map_err(|e| e.to_string())?;
    #[cfg(target_os = "macos")]
    if let Err(error) = crate::platform::menu_bar_icon::install(&tray) {
        app.remove_tray_by_id(TRAY_ID);
        return Err(error);
    }
    #[cfg(not(target_os = "macos"))]
    let _ = tray;
    Ok(())
}
pub fn initialize(app: &tauri::AppHandle) {
    let result = (|| -> Result<(), String> {
        let config = crate::config::get(app);
        config.migrate(
            "settings.json",
            "general",
            config.legacy_json::<Preferences>("general-settings.json")?,
            Preferences::default(),
        )?;
        let value: Preferences = crate::config::read(app, "general")?;
        validate_session_minutes(value.launcher_session_minutes)?;
        *app.state::<GeneralSettings>()
            .0
            .lock()
            .map_err(|e| e.to_string())? = value.clone();
        set_tray(app, value.show_tray)
    })();
    if let Err(error) = result {
        eprintln!("General settings: {error}");
    }
}
#[tauri::command]
pub fn general_settings(app: tauri::AppHandle) -> Result<Status, String> {
    Ok(Status {
        launch_at_login: app.autolaunch().is_enabled().map_err(|e| e.to_string())?,
        show_tray: app.tray_by_id(TRAY_ID).is_some(),
        launcher_session_minutes: launcher_session_minutes(&app),
    })
}
#[tauri::command]
pub fn set_general_setting(
    app: tauri::AppHandle,
    setting: String,
    enabled: bool,
) -> Result<Status, String> {
    match setting.as_str() {
        "launch_at_login" => {
            let manager = app.autolaunch();
            if enabled {
                manager.enable()
            } else {
                manager.disable()
            }
            .map_err(|e| e.to_string())?;
        }
        "show_tray" => {
            let state = app.state::<GeneralSettings>();
            let mut value = state.0.lock().map_err(|e| e.to_string())?;
            let old_visible = app.tray_by_id(TRAY_ID).is_some();
            set_tray(&app, enabled)?;
            let next = Preferences {
                show_tray: enabled,
                ..value.clone()
            };
            if let Err(error) = save(&app, &next) {
                let _ = set_tray(&app, old_visible);
                return Err(error);
            }
            *value = next;
        }
        _ => return Err("Unknown general setting".into()),
    }
    general_settings(app)
}

pub fn validate_configuration(config: &crate::config::Config) -> Result<(), String> {
    config
        .read::<Preferences>("settings.json", "general", Preferences::default())
        .and_then(|value| validate_session_minutes(value.launcher_session_minutes))
}
pub fn reload(app: &tauri::AppHandle) -> Result<(), String> {
    let value: Preferences = crate::config::read(app, "general")?;
    validate_session_minutes(value.launcher_session_minutes)?;
    set_tray(app, value.show_tray)?;
    *app.state::<GeneralSettings>()
        .0
        .lock()
        .map_err(|e| e.to_string())? = value;
    Ok(())
}

pub fn launcher_session_minutes(app: &tauri::AppHandle) -> Option<u32> {
    app.state::<GeneralSettings>()
        .0
        .lock()
        .unwrap()
        .launcher_session_minutes
}

#[tauri::command]
pub fn set_launcher_session_timeout(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    minutes: Option<u32>,
) -> Result<(), String> {
    if window.label() != "settings" {
        return Err("Launcher preferences belong to Settings.".into());
    }
    validate_session_minutes(minutes)?;
    let state = app.state::<GeneralSettings>();
    let mut value = state.0.lock().map_err(|error| error.to_string())?;
    let next = Preferences {
        launcher_session_minutes: minutes,
        ..value.clone()
    };
    save(&app, &next)?;
    *value = next;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn old_settings_default_to_five_minutes_and_always_round_trips() {
        let old: Preferences = serde_json::from_str(r#"{"show_tray":false}"#).unwrap();
        assert_eq!(old.launcher_session_minutes, Some(5));
        let always = Preferences {
            launcher_session_minutes: None,
            ..old
        };
        let restored: Preferences =
            serde_json::from_value(serde_json::to_value(always).unwrap()).unwrap();
        assert_eq!(restored.launcher_session_minutes, None);
        assert!(!restored.show_tray);
    }
    #[test]
    fn durations_are_bounded_and_integral() {
        for minutes in [None, Some(0), Some(1), Some(12), Some(10080)] {
            assert!(validate_session_minutes(minutes).is_ok());
        }
        assert!(validate_session_minutes(Some(10081)).is_err());
        for minutes in ["-1", "1.5", "\"five\""] {
            assert!(serde_json::from_str::<Preferences>(&format!(
                r#"{{"show_tray":true,"launcher_session_minutes":{minutes}}}"#
            ))
            .is_err());
        }
    }
}
