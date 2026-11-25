//! Active sessions belong to this installation, not the synced preferences.
use super::model::SavedSession;
use crate::config::files;
use std::path::{Path, PathBuf};
use tauri::Manager;

fn path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    Ok(app
        .path()
        .app_config_dir()
        .map_err(|e| e.to_string())?
        .join("keep-awake-session.json"))
}
pub fn load(app: &tauri::AppHandle) -> Result<Option<SavedSession>, String> {
    read(&path(app)?)
}
pub fn save(app: &tauri::AppHandle, session: &Option<SavedSession>) -> Result<(), String> {
    write(&path(app)?, session)
}
pub(super) fn read(path: &Path) -> Result<Option<SavedSession>, String> {
    match files::json(path)? {
        None => Ok(None),
        Some(value) => serde_json::from_value(value).map_err(|e| e.to_string()),
    }
}
pub(super) fn write(path: &Path, session: &Option<SavedSession>) -> Result<(), String> {
    let previous = files::read(path)?;
    files::write(
        path,
        &serde_json::to_value(session).map_err(|e| e.to_string())?,
        previous.as_deref(),
    )
}
