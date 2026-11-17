use serde::{Deserialize, Serialize};
use std::fs;
use tauri::Manager;

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Preferences {
    pub show_menu_bar_icon: bool,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            show_menu_bar_icon: true,
        }
    }
}
fn path(app: &tauri::AppHandle) -> Result<std::path::PathBuf, String> {
    Ok(app
        .path()
        .app_config_dir()
        .map_err(|e| e.to_string())?
        .join("keep-awake.json"))
}
pub fn load(app: &tauri::AppHandle) -> Result<Preferences, String> {
    match fs::read(path(app)?) {
        Ok(bytes) => serde_json::from_slice(&bytes).map_err(|e| e.to_string()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Preferences::default()),
        Err(error) => Err(error.to_string()),
    }
}
pub fn save(app: &tauri::AppHandle, preferences: &Preferences) -> Result<(), String> {
    let path = path(app)?;
    fs::create_dir_all(path.parent().ok_or("Settings directory unavailable")?)
        .map_err(|e| e.to_string())?;
    let temporary = path.with_extension("tmp");
    fs::write(
        &temporary,
        serde_json::to_vec(preferences).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    fs::rename(temporary, path).map_err(|e| e.to_string())
}
