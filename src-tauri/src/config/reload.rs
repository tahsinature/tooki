use super::*;
use serde::Serialize;
use tauri::Emitter;

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Category {
    name: String,
    loaded_at: Option<u64>,
    detail: String,
    error: String,
}
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Report {
    folder: String,
    last_loaded_at: Option<u64>,
    legacy_snippets: bool,
    categories: Vec<Category>,
    warnings: Vec<String>,
}
struct LoadState(Mutex<Report>, tokio::sync::Mutex<()>);
fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
fn report(config: &Config) -> Report {
    let timestamp = now();
    let categories: Vec<_> = snapshot::GROUPS
        .iter()
        .map(|name| {
            let result = validation::group(config, name).map(|detail| {
                if name.ends_with(".json")
                    && matches!(config.bytes(&config.root.join(name)), Ok(None))
                {
                    "File missing; using defaults".into()
                } else {
                    detail
                }
            });
            Category {
                name: name.to_string(),
                loaded_at: result.as_ref().ok().map(|_| timestamp),
                detail: result.as_ref().ok().cloned().unwrap_or_default(),
                error: result.err().unwrap_or_default(),
            }
        })
        .collect();
    Report {
        folder: config.root.display().to_string(),
        last_loaded_at: categories
            .iter()
            .all(|v| v.error.is_empty())
            .then_some(timestamp),
        legacy_snippets: std::fs::symlink_metadata(config.root.join("snippets.json")).is_ok(),
        categories,
        warnings: vec![],
    }
}
pub fn initialize(app: &tauri::AppHandle) {
    let mut value = report(&get(app));
    value.warnings = runtime_warnings(app);
    app.manage(LoadState(Mutex::new(value), tokio::sync::Mutex::new(())));
}
fn runtime_warnings(app: &tauri::AppHandle) -> Vec<String> {
    let mut warnings = vec![];
    if let Err(error) = crate::launcher_shortcut::get_launcher_shortcut(app.state()) {
        warnings.push(format!("Launcher: {error}"));
    }
    if let Ok(values) = crate::applications::preferences::application_preferences(app.clone()) {
        for (id, value) in values {
            if !value.shortcut_error.is_empty() {
                warnings.push(format!("{id}: {}", value.shortcut_error));
            }
        }
    }
    warnings
}
#[tauri::command]
pub fn configuration_status(app: tauri::AppHandle) -> Result<Report, String> {
    let mut report = app
        .state::<LoadState>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .clone();
    // Runtime assignments may change in the UI after the last disk load.
    report.warnings.extend(runtime_warnings(&app));
    report.warnings.sort();
    report.warnings.dedup();
    Ok(report)
}

// Build and validate a separate snapshot. A broken category keeps its last
// loaded bytes, including for frontend readers and automatic snippet expansion.
fn load(config: &Config, previous: &Report) -> Result<Report, String> {
    let _writes = WRITES.lock().map_err(|e| e.to_string())?;
    let candidate = Config::new(config.root.clone(), config.legacy.clone(), false);
    let mut next = report(&candidate);
    let mut loaded = config.snapshot.lock().map_err(|e| e.to_string())?;
    let incoming = candidate.snapshot.lock().map_err(|e| e.to_string())?;
    for category in &mut next.categories {
        if category.error.is_empty() {
            loaded.replace_group(&incoming, &config.root, &category.name);
        } else if let Some(old) = previous.categories.iter().find(|v| v.name == category.name) {
            category.loaded_at = old.loaded_at;
            category.detail = if old.loaded_at.is_some() {
                "Previous configuration retained".into()
            } else {
                "Not loaded".into()
            };
        }
    }
    if next.last_loaded_at.is_none() {
        next.last_loaded_at = previous.last_loaded_at;
    }
    Ok(next)
}
#[tauri::command]
pub async fn reload_configuration(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<Report, String> {
    if window.label() != "settings" {
        return Err("Reload configuration from Settings.".into());
    }
    let state = app.state::<LoadState>();
    let _reload = state
        .1
        .try_lock()
        .map_err(|_| "Configuration is already loading")?;
    let previous = state.0.lock().map_err(|e| e.to_string())?.clone();
    let config = (*get(&app)).clone();
    let mut next = tauri::async_runtime::spawn_blocking(move || load(&config, &previous))
        .await
        .map_err(|e| e.to_string())??;
    let (tx, rx) = tokio::sync::oneshot::channel();
    let handle = app.clone();
    app.run_on_main_thread(move || {
        let mut errors = vec![];
        for (name, result) in [
            ("General", crate::general_settings::reload(&handle)),
            ("Hyper Key", crate::hyper::reload_preferences(&handle)),
            ("Keep Awake", crate::keep_awake::reload_preferences(&handle)),
            (
                "Shelferry",
                crate::extensions::shelferry::reload_preferences(&handle),
            ),
            ("Clipboard", crate::clipboard::preferences::reload(&handle)),
            (
                "Launcher shortcut",
                crate::launcher_shortcut::reload(&handle),
            ),
            (
                "Shortcuts",
                crate::applications::preferences::reload(&handle),
            ),
        ] {
            if let Err(error) = result {
                errors.push(format!("{name}: {error}"));
            }
        }
        let _ = tx.send(errors);
    })
    .map_err(|e| e.to_string())?;
    next.warnings = rx.await.map_err(|e| e.to_string())?;
    match crate::snippets::reload_storage(&app) {
        Ok(()) => {
            if let Err(error) = crate::snippets::configure(&app).await {
                next.warnings.push(format!("Snippet expansion: {error}"));
            }
        }
        Err(error) => next.warnings.push(error),
    }
    next.warnings.extend(runtime_warnings(&app));
    *state.0.lock().map_err(|e| e.to_string())? = next.clone();
    let _ = app.emit("portable-config-changed", ());
    let _ = app.emit("snippets-changed", ());
    let errors: Vec<_> = next
        .categories
        .iter()
        .filter(|v| !v.error.is_empty())
        .map(|v| format!("{}: {}", v.name, v.error))
        .collect();
    let _ = app.emit("portable-config-error", errors.join("\n"));
    Ok(next)
}
#[tauri::command]
pub async fn open_configuration_folder(app: tauri::AppHandle) -> Result<(), String> {
    let root = get(&app).root.clone();
    tauri::async_runtime::spawn_blocking(move || {
        crate::platform::file_action(&app, "open", &root, None).map(|_| ())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[cfg(test)]
#[path = "reload_tests.rs"]
mod tests;
