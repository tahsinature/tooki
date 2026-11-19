use super::{model::Settings, Clipboard};
use crate::config::{self, files};
use serde_json::json;
use tauri::{Emitter, Manager};
pub fn local_settings(app: &tauri::AppHandle) -> Result<Settings, String> {
    let config = config::get(app);
    let mut legacy: Settings = files::json(&config.legacy.join("clipboard/settings.json"))?
        .map(serde_json::from_value)
        .transpose()
        .map_err(|e| e.to_string())?
        .unwrap_or_default();
    let local = files::json(&config.legacy.join("clipboard/local-settings.json"))?;
    if let Some(value) = local.as_ref().and_then(|v| v["persistHistory"].as_bool()) {
        legacy.persist_history = value;
    }
    legacy.validate()?;
    Ok(legacy)
}
pub fn load(app: &tauri::AppHandle) -> Result<Settings, String> {
    let config = config::get(app);
    let legacy = local_settings(app)?;
    let persisted = legacy.persist_history;
    let mut old = serde_json::to_value(&legacy).map_err(|e| e.to_string())?;
    old.as_object_mut().unwrap().remove("persistHistory");
    let mut default = serde_json::to_value(Settings::default()).unwrap();
    default.as_object_mut().unwrap().remove("persistHistory");
    config.migrate("settings.json", "clipboard", old, default.clone())?;
    let mut value: serde_json::Value = config.read("settings.json", "clipboard", default)?;
    value
        .as_object_mut()
        .ok_or("settings.json/clipboard must be an object")?
        .insert("persistHistory".into(), json!(persisted));
    let settings: Settings = serde_json::from_value(value).map_err(|e| e.to_string())?;
    settings.validate()?;
    Ok(settings)
}
pub fn save(app: &tauri::AppHandle, next: &Settings) -> Result<(), String> {
    let mut portable = serde_json::to_value(next).map_err(|e| e.to_string())?;
    portable.as_object_mut().unwrap().remove("persistHistory");
    config::save(app, "clipboard", &portable)?;
    let path = config::legacy_path(app, "clipboard/local-settings.json");
    let before = files::read(&path)?;
    files::write(
        &path,
        &json!({"persistHistory":next.persist_history}),
        before.as_deref(),
    )
}
pub fn reload(app: &tauri::AppHandle) -> Result<(), String> {
    let next = load(app)?;
    let state = app.state::<Clipboard>();
    let mut current = state.settings.lock().map_err(|e| e.to_string())?;
    // Do not switch history storage in response to edits from another computer.
    let next = Settings {
        persist_history: current.persist_history,
        ..next
    };
    if serde_json::to_value(&*current).unwrap() != serde_json::to_value(&next).unwrap() {
        *current = next;
        let _ = app.emit("clipboard-changed", ());
    }
    Ok(())
}

pub fn validate_configuration(config: &config::Config) -> Result<(), String> {
    config
        .read::<Settings>("settings.json", "clipboard", Settings::default())?
        .validate()
}
