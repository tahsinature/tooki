pub mod files;
mod frontend;
mod reload;
mod snapshot;
#[cfg(test)]
mod tests;
mod theme_validation;
mod validation;
pub use frontend::*;
pub use reload::*;
use serde::{de::DeserializeOwned, Serialize};
use serde_json::{json, Value};
use std::{
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
};
use tauri::Manager;
pub(crate) static WRITES: Mutex<()> = Mutex::new(());
#[derive(Clone)]
pub struct Config {
    pub root: PathBuf,
    pub legacy: PathBuf,
    pub import_legacy: bool,
    snapshot: Arc<Mutex<snapshot::Snapshot>>,
    themes_initialized: Arc<AtomicBool>,
}
impl Config {
    pub fn new(root: PathBuf, legacy: PathBuf, import_legacy: bool) -> Self {
        let snapshot = Arc::new(Mutex::new(snapshot::Snapshot::load(&root)));
        let themes_initialized = Arc::new(AtomicBool::new(root.join("themes").exists()));
        Self {
            root,
            legacy,
            import_legacy,
            snapshot,
            themes_initialized,
        }
    }
    pub fn bytes(&self, path: &Path) -> Result<Option<Vec<u8>>, String> {
        self.snapshot.lock().map_err(|e| e.to_string())?.read(path)
    }
    pub fn entries(&self, path: &Path) -> Result<Vec<PathBuf>, String> {
        self.snapshot
            .lock()
            .map_err(|e| e.to_string())?
            .entries(path)
    }
    pub fn json(&self, path: &Path) -> Result<Option<Value>, String> {
        self.bytes(path)?
            .map(|bytes| {
                serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))
            })
            .transpose()
    }
    pub fn refresh_group(&self, group: &str) {
        self.snapshot.lock().unwrap().reload(&self.root, group);
    }
    pub fn write_file(
        &self,
        path: &Path,
        value: &Value,
        expected: Option<&[u8]>,
    ) -> Result<(), String> {
        files::write(path, value, expected)?;
        self.snapshot.lock().unwrap().saved(
            path,
            Some(serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?),
        );
        Ok(())
    }
    pub fn remove_file(&self, path: &Path, expected: Option<&[u8]>) -> Result<(), String> {
        if files::read(path)?.as_deref() != expected {
            return Err(format!(
                "{} changed on disk. Reload before deleting.",
                path.display()
            ));
        }
        std::fs::remove_file(path).map_err(|e| e.to_string())?;
        self.snapshot.lock().unwrap().saved(path, None);
        Ok(())
    }

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
        let value = self
            .json(&self.root.join(name))?
            .unwrap_or(json!({"version":1}));
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
        let before = self.bytes(&path)?;
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
        self.write_file(&path, &value, before.as_deref())
    }
    pub fn migrate<T: Serialize>(
        &self,
        document: &str,
        section: &str,
        legacy: T,
        default: T,
    ) -> Result<(), String> {
        if self.document(document)?.get(section).is_some() {
            return Ok(());
        }
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
    let config = Config::new(root, legacy, import_legacy);
    // Invalid synced files should report an error, not prevent the application opening.
    for name in ["settings.json", "shortcuts.json"] {
        if std::fs::symlink_metadata(config.root.join(name)).is_err() {
            config.update(name, |_| Ok(()))?;
        }
    }
    app.manage(config);
    Ok(())
}
pub fn initialize_report(app: &tauri::AppHandle) {
    reload::initialize(app);
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
