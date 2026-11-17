use serde::{Deserialize, Serialize};
use std::{fs, sync::Mutex};
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

fn path(app: &tauri::AppHandle) -> Result<std::path::PathBuf, String> {
    Ok(app
        .path()
        .app_config_dir()
        .map_err(|e| e.to_string())?
        .join("general-settings.json"))
}
fn save(app: &tauri::AppHandle, value: &Preferences) -> Result<(), String> {
    let path = path(app)?;
    fs::create_dir_all(path.parent().ok_or("Missing settings directory")?)
        .map_err(|e| e.to_string())?;
    let temporary = path.with_extension("tmp");
    fs::write(
        &temporary,
        serde_json::to_vec(value).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    fs::rename(temporary, path).map_err(|e| e.to_string())
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
        let value = match fs::read(path(app)?) {
            Ok(bytes) => serde_json::from_slice(&bytes).map_err(|e| e.to_string())?,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Preferences::default(),
            Err(e) => return Err(e.to_string()),
        };
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
