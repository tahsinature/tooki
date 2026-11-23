use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, sync::Mutex};
use tauri::{Emitter, Manager};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};
#[derive(Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct Preference {
    pub favorite: bool,
    // Preserve legacy synced data; aliases no longer affect search or editing.
    pub alias: String,
    pub shortcut: String,
    #[serde(skip, default)]
    pub shortcut_error: String,
}
#[derive(Default)]
pub struct Preferences(pub Mutex<BTreeMap<String, Preference>>);
fn save_one(app: &tauri::AppHandle, id: &str, value: &Preference) -> Result<(), String> {
    let key = super::identity::storage_key(app, id);
    crate::config::get(app).update("shortcuts.json", |doc| {
        if doc.get("assignments").is_none() {
            doc["assignments"] = serde_json::json!({});
        }
        let assignments = doc["assignments"]
            .as_object_mut()
            .ok_or("shortcuts.json/assignments must be an object")?;
        assignments.insert(key, serde_json::to_value(value).map_err(|e| e.to_string())?);
        Ok(())
    })
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
                    if id.starts_with("command:system.") {
                        use tauri_plugin_dialog::DialogExt;
                        app.dialog()
                            .message(error)
                            .title("System Actions")
                            .show(|_| {});
                    }
                }
            });
        })
        .map_err(|e| format!("Shortcut is unavailable or already assigned: {e}"))
}
pub fn initialize(app: &tauri::AppHandle) {
    let result = (|| -> Result<(), String> {
        let config = crate::config::get(app);
        let old =
            config.legacy_json::<BTreeMap<String, Preference>>("application-preferences.json")?;
        let portable: BTreeMap<_, _> = old
            .into_iter()
            .map(|(id, value)| (super::identity::storage_key(app, &id), value))
            .collect();
        config.migrate(
            "shortcuts.json",
            "assignments",
            portable,
            BTreeMap::<String, Preference>::new(),
        )?;
        reload(app)
    })();
    if let Err(error) = result {
        eprintln!("Shortcut configuration: {error}");
    }
}
pub fn reload(app: &tauri::AppHandle) -> Result<(), String> {
    let stored: BTreeMap<String, Preference> =
        crate::config::get(app).read("shortcuts.json", "assignments", BTreeMap::new())?;
    let mut next: BTreeMap<String, Preference> = stored
        .into_iter()
        .map(|(key, preference)| (super::identity::runtime_id(app, &key), preference))
        .collect();
    let state = app.state::<Preferences>();
    let mut current = state.0.lock().map_err(|e| e.to_string())?;
    // Validate before releasing any existing registrations.
    for value in next.values() {
        if !value.shortcut.is_empty() {
            value
                .shortcut
                .parse::<Shortcut>()
                .map_err(|e| e.to_string())?;
        }
    }
    for (id, old) in current.iter() {
        if next.get(id).is_none_or(|v| v.shortcut != old.shortcut)
            && !old.shortcut.is_empty()
            && old.shortcut_error.is_empty()
        {
            app.global_shortcut()
                .unregister(old.shortcut.as_str())
                .map_err(|e| e.to_string())?;
        }
    }
    for (id, value) in &mut next {
        if let Some(old) = current
            .get(id)
            .filter(|old| old.shortcut == value.shortcut && old.shortcut_error.is_empty())
        {
            value.shortcut_error = old.shortcut_error.clone();
        } else if !value.shortcut.is_empty() {
            value.shortcut_error = if id.starts_with("bundle:") {
                "Application is not installed on this computer. Assignment is saved.".into()
            } else {
                register(app, id, &value.shortcut).err().unwrap_or_default()
            };
        }
    }
    if *current != next {
        *current = next;
        let _ = app.emit("application-preferences-changed", &*current);
    }
    Ok(())
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
    updated.insert(id.clone(), next.clone());
    if let Err(error) = save_one(&app, &id, &next) {
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
            let _ = save_one(&app, &id, &old);
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
