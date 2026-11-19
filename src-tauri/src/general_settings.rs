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
}
impl Default for Preferences {
    fn default() -> Self {
        Self { show_tray: true }
    }
}
#[derive(Default)]
pub struct GeneralSettings(Mutex<Preferences>);
#[derive(Serialize)]
pub struct Status {
    launch_at_login: bool,
    show_tray: bool,
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
            let next = Preferences { show_tray: enabled };
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
        .map(|_| ())
}
pub fn reload(app: &tauri::AppHandle) -> Result<(), String> {
    let value: Preferences = crate::config::read(app, "general")?;
    set_tray(app, value.show_tray)?;
    *app.state::<GeneralSettings>()
        .0
        .lock()
        .map_err(|e| e.to_string())? = value;
    Ok(())
}
