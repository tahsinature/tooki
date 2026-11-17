pub mod actions;
mod identity;
#[cfg(any(target_os = "linux", test))]
#[allow(dead_code)]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
pub mod preferences;
#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "linux")]
use linux as platform;
#[cfg(target_os = "macos")]
use macos as platform;
use serde::{Deserialize, Serialize};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Mutex,
};
use tauri::{Emitter, Manager};
#[cfg(target_os = "windows")]
use windows as platform;

#[derive(Clone, Serialize, Deserialize)]
pub struct Application {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub bundle_id: Option<String>,
    #[serde(default)]
    pub icon: Option<String>,
}
#[derive(Default)]
pub struct Catalog {
    apps: Mutex<Vec<Application>>,
    refreshing: AtomicBool,
}

// Searches read an in-memory snapshot. Discovery never blocks the UI thread.
pub fn refresh(app: &tauri::AppHandle) {
    if app
        .state::<Catalog>()
        .refreshing
        .swap(true, Ordering::AcqRel)
    {
        return;
    }
    let _ = app.emit("applications-refreshing", true);
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let catalog = app.state::<Catalog>();
        match platform::scan() {
            Ok(mut apps) => {
                apps.sort_by_cached_key(|item| item.name.to_lowercase());
                if let Ok(mut cached) = catalog.apps.lock() {
                    *cached = apps.clone();
                }
                let _ = app.emit("applications-changed", apps);
                let handle = app.clone();
                let _ = app.run_on_main_thread(move || {
                    if let Err(error) = preferences::reload(&handle) {
                        eprintln!("Shortcut reload: {error}");
                    }
                });
            }
            Err(error) => {
                let _ = app.emit("applications-error", error);
            }
        }
        catalog.refreshing.store(false, Ordering::Release);
        let _ = app.emit("applications-refreshing", false);
    });
}
#[tauri::command]
pub fn list_applications(app: tauri::AppHandle) -> Result<Vec<Application>, String> {
    let snapshot = app
        .state::<Catalog>()
        .apps
        .lock()
        .map_err(|e| e.to_string())?
        .clone();
    refresh(&app);
    Ok(snapshot)
}
#[tauri::command]
pub async fn launch_application(app: tauri::AppHandle, id: String) -> Result<(), String> {
    let entry = find(&app, &id)?;
    tauri::async_runtime::spawn_blocking(move || platform::launch(&entry.id))
        .await
        .map_err(|e| e.to_string())?
}

pub fn find(app: &tauri::AppHandle, id: &str) -> Result<Application, String> {
    app.state::<Catalog>()
        .apps
        .lock()
        .map_err(|e| e.to_string())?
        .iter()
        .find(|entry| entry.id == id)
        .cloned()
        .ok_or_else(|| "Application is no longer in the catalog. Search again.".into())
}
