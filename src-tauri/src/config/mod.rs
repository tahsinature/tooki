pub mod files;
mod frontend;
#[cfg(test)]
mod tests;
mod watch;
pub use frontend::*;
use serde::{de::DeserializeOwned, Serialize};
use serde_json::{json, Value};
use std::{
    path::{Path, PathBuf},
    sync::Mutex,
};
use tauri::Manager;
static WRITES: Mutex<()> = Mutex::new(());
pub struct Config {
    pub root: PathBuf,
    pub legacy: PathBuf,
    pub import_legacy: bool,
}
impl Config {
    pub fn read<T: DeserializeOwned>(
        &self,
        document: &str,
        section: &str,
        default: T,
    ) -> Result<T, String> {
        let value = self.document(document)?;
        match value.get(section) {
            Some(value) => serde_json::from_value(value.clone())
                .map_err(|e| format!("{document}/{section}: {e}")),
            None => Ok(default),
        }
    }
    fn document(&self, name: &str) -> Result<Value, String> {
        let value = files::json(&self.root.join(name))?.unwrap_or(json!({"version":1}));
        if !value.is_object() || value["version"] != 1 {
            return Err(format!("Unsupported or invalid configuration: {name}"));
        }
        Ok(value)
    }
    pub fn set<T: Serialize>(
        &self,
        document: &str,
        section: &str,
        value: &T,
    ) -> Result<(), String> {
        self.update(document, |doc| {
            doc[section] = serde_json::to_value(value).map_err(|e| e.to_string())?;
            Ok(())
        })
    }
    pub fn update(
        &self,
        document: &str,
        f: impl FnOnce(&mut Value) -> Result<(), String>,
    ) -> Result<(), String> {
        let _guard = WRITES.lock().map_err(|e| e.to_string())?;
        let path = self.root.join(document);
        let before = files::read(&path)?;
        let mut value = self.document(document)?;
        f(&mut value)?;
        if before
            .as_ref()
            .and_then(|b| serde_json::from_slice::<Value>(b).ok())
            .as_ref()
            == Some(&value)
        {
            return Ok(());
        }
        files::write(&path, &value, before.as_deref())
    }
    pub fn migrate<T: Serialize>(
        &self,
        document: &str,
        section: &str,
        legacy: T,
        default: T,
    ) -> Result<(), String> {
        self.update(document, |doc| {
            if doc.get(section).is_none() {
                doc[section] =
                    serde_json::to_value(if self.import_legacy { legacy } else { default })
                        .map_err(|e| e.to_string())?;
            }
            Ok(())
        })
    }
    pub fn legacy_json<T: DeserializeOwned + Default>(&self, path: &str) -> Result<T, String> {
        if !self.import_legacy {
            return Ok(T::default());
        }
        files::json(&self.legacy.join(path))?
            .map(serde_json::from_value)
            .transpose()
            .map_err(|e| e.to_string())
            .map(|v| v.unwrap_or_default())
    }
}
pub fn get(app: &tauri::AppHandle) -> tauri::State<'_, Config> {
    app.state::<Config>()
}
pub fn read<T: DeserializeOwned + Default>(
    app: &tauri::AppHandle,
    section: &str,
) -> Result<T, String> {
    get(app).read("settings.json", section, T::default())
}
pub fn save<T: Serialize>(app: &tauri::AppHandle, section: &str, value: &T) -> Result<(), String> {
    get(app).set("settings.json", section, value)
}
pub fn initialize(app: &tauri::AppHandle) -> Result<(), String> {
    let root = app
        .path()
        .home_dir()
        .map_err(|e| e.to_string())?
        .join(".config/tooki");
    let legacy = app.path().app_config_dir().map_err(|e| e.to_string())?;
    files::directory(&root)?;
    let marker = legacy.join("portable-migration.json");
    let prior = files::json(&marker)?;
    let import_legacy = prior
        .as_ref()
        .and_then(|v| v["pending"].as_bool())
        .unwrap_or(!root.join("settings.json").exists());
    if prior.is_none() {
        files::write(&marker, &json!({"pending":import_legacy}), None)?;
    }
    let config = Config {
        root,
        legacy,
        import_legacy,
    };
    // Invalid synced files should report an error, not prevent the application opening.
    for name in ["settings.json", "shortcuts.json"] {
        if !config.root.join(name).exists() {
            config.update(name, |_| Ok(()))?;
        }
    }
    app.manage(config);
    Ok(())
}
pub fn start_watching(app: &tauri::AppHandle) {
    watch::start(app);
}
pub fn legacy_path(app: &tauri::AppHandle, name: &str) -> PathBuf {
    get(app).legacy.join(Path::new(name))
}

pub fn finish_frontend_migration(config: &Config) -> Result<(), String> {
    let _guard = WRITES.lock().map_err(|e| e.to_string())?;
    let doc = config.document("settings.json")?;
    if doc.get("interface").is_some()
        && doc.get("appearance").is_some()
        && config.root.join("themes").exists()
    {
        let path = config.legacy.join("portable-migration.json");
        let old = files::read(&path)?;
        if old
            .as_ref()
            .and_then(|b| serde_json::from_slice::<Value>(b).ok())
            .is_some_and(|v| v["pending"] == true)
        {
            files::write(&path, &json!({"pending":false}), old.as_deref())?;
        }
    }
    Ok(())
}
