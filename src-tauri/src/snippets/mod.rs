mod automatic;
pub mod commands;
mod engine;
mod legacy;
mod migration;
mod model;
mod native;
mod runner;
mod storage;
#[cfg(test)]
mod tests;

use engine::{evaluate, Context};
use model::*;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::BTreeMap,
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    },
    time::Instant,
};
use tauri::{Emitter, Manager};
use tauri_plugin_clipboard_manager::ClipboardExt;

#[derive(Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Pending {
    pub id: String,
    pub arguments: BTreeMap<String, String>,
    pub context: String,
    pub error: String,
}
struct Prepared {
    text: String,
    id: String,
    revision: i64,
    context: String,
    pid: i32,
    created: Instant,
}
pub struct Snippets {
    store: Mutex<Result<storage::Storage, String>>,
    pending: Mutex<Option<Pending>>,
    prepared: Mutex<BTreeMap<u64, Prepared>>,
    next_ticket: AtomicU64,
    target: Mutex<i32>,
}
pub fn initialize(app: &tauri::AppHandle) {
    let store = (|| {
        let config = crate::config::get(app);
        let mut store = storage::Storage::open(&config.root, &config.legacy, config.import_legacy)?;
        let source = config.root.join("snippets.json");
        let imported: bool = config.read("settings.json", "swiftSnippetsImported", false)?;
        if source.exists() && !imported {
            migration::import_swift(&config.root, &source, &mut store)?;
            config.set("settings.json", "swiftSnippetsImported", &true)?;
        }
        Ok::<_, String>(store)
    })();
    app.manage(Snippets {
        store: Mutex::new(store),
        pending: Mutex::new(None),
        prepared: Mutex::new(BTreeMap::new()),
        next_ticket: AtomicU64::new(1),
        target: Mutex::new(0),
    });
    automatic::initialize(app);
}
fn with_store<T>(
    app: &tauri::AppHandle,
    f: impl FnOnce(&mut storage::Storage) -> Result<T, String>,
) -> Result<T, String> {
    let state = app.state::<Snippets>();
    let mut guard = state.store.lock().map_err(|e| e.to_string())?;
    f(guard.as_mut().map_err(|e| e.clone())?)
}
fn record(app: &tauri::AppHandle, id: &str) -> Result<Record, String> {
    with_store(app, |store| {
        store
            .list()?
            .into_iter()
            .find(|record| record.definition.id == id)
            .ok_or("Snippet no longer exists.".into())
    })
}
pub async fn configure(app: &tauri::AppHandle) -> Result<Value, String> {
    let (records, preferences) =
        with_store(app, |store| Ok((store.list()?, store.preferences()?)))?;
    let triggers: Vec<_> = records
        .iter()
        .filter(|r| r.configuration.automatic)
        .flat_map(Record::invocations)
        .collect();
    native::call(app,"configure",json!({"enabled":preferences.automatic,"triggers":triggers,"excludedApps":preferences.excluded_apps})).await
}
fn args_map(args: &Value) -> Result<BTreeMap<String, String>, String> {
    serde_json::from_value(args.get("arguments").cloned().unwrap_or(json!({})))
        .map_err(|e| e.to_string())
}
pub async fn open(app: &tauri::AppHandle) -> Result<(), String> {
    *app.state::<Snippets>().pending.lock().unwrap() = None;
    native::call(app, "cancel", json!({})).await?;
    crate::launcher_presentation::request_tool(app, "command:snippets.open")
        .map_err(|e| e.to_string())
}
pub fn stop(app: &tauri::AppHandle) {
    let handle = app.clone();
    tauri::async_runtime::spawn(async move {
        let _ = native::call(&handle, "configure", json!({"enabled":false,"triggers":[]})).await;
    });
}
