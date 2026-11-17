use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, fs, sync::Mutex};
use tauri::{Emitter, Manager};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};
#[derive(Clone, Default, Serialize, Deserialize)]
pub struct Preference {
    pub favorite: bool,
    pub alias: String,
    pub shortcut: String,
    #[serde(skip_deserializing, default)]
    pub shortcut_error: String,
}
#[derive(Default)]
pub struct Preferences(pub Mutex<BTreeMap<String, Preference>>);
fn save(app: &tauri::AppHandle, values: &BTreeMap<String, Preference>) -> Result<(), String> {
    let directory = app.path().app_config_dir().map_err(|e| e.to_string())?;
    fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
    let path = directory.join("application-preferences.json");
    // Keep an existing file intact if serialization or writing fails.
    let content = serde_json::to_vec(values).map_err(|e| e.to_string())?;
    let temporary = directory.join("application-preferences.tmp");
    fs::write(&temporary, content).map_err(|e| e.to_string())?;
    fs::rename(temporary, path).map_err(|e| e.to_string())
}
fn register(app: &tauri::AppHandle, id: &str, shortcut: &str) -> Result<(), String> {
    if crate::tool_commands::find(id).is_some() && !crate::tool_commands::enabled(app, id) {
        return Err(crate::tool_commands::unavailable_reason(app, id)
            .unwrap_or_else(|| "Tool is disabled. Assignment is saved.".into()));
    }
    shortcut
        .parse::<Shortcut>()
        .map_err(|e| format!("Invalid shortcut: {e}"))?;
    if app.global_shortcut().is_registered(shortcut) {
        return Err("This shortcut is already assigned in Tooki.".into());
    }
    let id = id.to_string();
    app.global_shortcut()
        .on_shortcut(shortcut, move |app, _, event| {
            if event.state != ShortcutState::Pressed
                || app
                    .state::<crate::launcher_shortcut::LauncherShortcut>()
                    .is_recording()
            {
                return;
            }
            let app = app.clone();
            let id = id.clone();
            tauri::async_runtime::spawn(async move {
                let result = if crate::tool_commands::find(&id).is_some() {
                    crate::tool_commands::execute_tool_command(app.clone(), id.clone()).await
                } else {
                    super::launch_application(app.clone(), id.clone()).await
                };
                if let Err(error) = result {
                    use tauri::Emitter;
                    let _ = app.emit("applications-error", &error);
                    if id.starts_with("command:system.") || id.starts_with("command:shelf.") {
                        use tauri_plugin_dialog::DialogExt;
                        app.dialog()
                            .message(error)
                            .title(if id.starts_with("command:shelf.") {
                                "Shelferry"
                            } else {
                                "System Actions"
                            })
                            .show(|_| {});
                    }
                }
            });
        })
        .map_err(|e| format!("Shortcut is unavailable or already assigned: {e}"))
}
pub fn initialize(app: &tauri::AppHandle) {
    let result = app
        .path()
        .app_config_dir()
        .ok()
        .and_then(|dir| fs::read(dir.join("application-preferences.json")).ok());
    let Some(bytes) = result else {
        return;
    };
    let Ok(mut values) = serde_json::from_slice::<BTreeMap<String, Preference>>(&bytes) else {
        eprintln!("Could not read application preferences");
        return;
    };
    for (id, value) in &mut values {
        if !value.shortcut.is_empty() {
            value.shortcut_error = register(app, id, &value.shortcut).err().unwrap_or_default();
        }
    }
    *app.state::<Preferences>().0.lock().unwrap() = values;
}
#[tauri::command]
pub fn application_preferences(
    app: tauri::AppHandle,
) -> Result<BTreeMap<String, Preference>, String> {
    Ok(app
        .state::<Preferences>()
        .0
        .lock()
        .map_err(|e| e.to_string())?
        .clone())
}
#[tauri::command]
pub fn update_application_preference(
    app: tauri::AppHandle,
    id: String,
    favorite: Option<bool>,
    alias: Option<String>,
    shortcut: Option<String>,
) -> Result<BTreeMap<String, Preference>, String> {
    if id.starts_with("command:") {
        if crate::tool_commands::find(&id).is_none() {
            return Err("Unknown command.".into());
        }
    } else {
        super::find(&app, &id)?;
    }
    let state = app.state::<Preferences>();
    let mut values = state.0.lock().map_err(|e| e.to_string())?;
    let old = values.get(&id).cloned().unwrap_or_default();
    let mut next = old.clone();
    if let Some(favorite) = favorite {
        next.favorite = favorite;
    }
    if let Some(alias) = alias {
        let alias = alias.trim().to_string();
        if alias.len() > 80 {
            return Err("Keep aliases under 80 characters.".into());
        }
        if !alias.is_empty()
            && values.iter().any(|(key, value)| {
                key != &id && value.alias.to_lowercase() == alias.to_lowercase()
            })
        {
            return Err("This alias is already assigned to another app or command.".into());
        }
        next.alias = alias;
    }
    let retry_registration = shortcut.is_some() && !old.shortcut_error.is_empty();
    if let Some(shortcut) = shortcut {
        next.shortcut = shortcut;
    }
    let changed = old.shortcut.parse::<Shortcut>().ok() != next.shortcut.parse::<Shortcut>().ok()
        || (old.shortcut.is_empty() != next.shortcut.is_empty())
        || retry_registration;
    let enabled = crate::tool_commands::enabled(&app, &id);
    if changed && !next.shortcut.is_empty() {
        next.shortcut
            .parse::<Shortcut>()
            .map_err(|e| format!("Invalid shortcut: {e}"))?;
        if enabled {
            register(&app, &id, &next.shortcut)?;
        }
    }
    let mut updated = values.clone();
    if changed {
        next.shortcut_error = if !enabled && !next.shortcut.is_empty() {
            crate::tool_commands::unavailable_reason(&app, &id)
                .unwrap_or_else(|| "Tool is disabled. Assignment is saved.".into())
        } else {
            String::new()
        };
    }
    updated.insert(id, next.clone());
    if let Err(error) = save(&app, &updated) {
        if changed && enabled && !next.shortcut.is_empty() {
            let _ = app.global_shortcut().unregister(next.shortcut.as_str());
        }
        return Err(format!("Could not save application preferences: {error}"));
    }
    if changed && !old.shortcut.is_empty() && old.shortcut_error.is_empty() {
        if let Err(error) = app.global_shortcut().unregister(old.shortcut.as_str()) {
            if !next.shortcut.is_empty() {
                let _ = app.global_shortcut().unregister(next.shortcut.as_str());
            }
            let _ = save(&app, &values);
            return Err(format!("Could not replace shortcut: {error}"));
        }
    }
    *values = updated;
    let _ = app.emit("application-preferences-changed", &*values);
    Ok(values.clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn preferences_round_trip_without_reusing_runtime_errors() {
        let mut values = BTreeMap::new();
        values.insert(
            "/Applications/Example.app".to_string(),
            Preference {
                favorite: true,
                alias: "work".into(),
                shortcut: "Super+Shift+KeyB".into(),
                shortcut_error: "old conflict".into(),
            },
        );
        let restored: BTreeMap<String, Preference> =
            serde_json::from_slice(&serde_json::to_vec(&values).unwrap()).unwrap();
        let preference = &restored["/Applications/Example.app"];
        assert!(preference.favorite);
        assert_eq!(preference.alias, "work");
        assert_eq!(preference.shortcut, "Super+Shift+KeyB");
        assert!(preference.shortcut_error.is_empty());
    }
}

/// Suspend disabled tools without deleting their assignments, and retry on enable.
pub fn sync_tool_shortcuts(app: &tauri::AppHandle, tool: &str, enabled: bool) {
    let state = app.state::<Preferences>();
    let mut values = state.0.lock().unwrap();
    for (id, preference) in values.iter_mut() {
        if !crate::tool_commands::find(id).is_some_and(|command| command.tool == tool)
            || preference.shortcut.is_empty()
        {
            continue;
        }
        if !enabled {
            if preference.shortcut_error.is_empty() {
                if let Err(error) = app
                    .global_shortcut()
                    .unregister(preference.shortcut.as_str())
                {
                    preference.shortcut_error = format!("Could not suspend shortcut: {error}");
                    continue;
                }
            }
            preference.shortcut_error = "Tool is disabled. Assignment is saved.".into();
        } else if !preference.shortcut_error.is_empty() {
            preference.shortcut_error = register(app, id, &preference.shortcut)
                .err()
                .unwrap_or_default();
        }
    }
    let _ = app.emit("application-preferences-changed", &*values);
}
