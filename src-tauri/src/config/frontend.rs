use super::*;
use tauri::Emitter;
pub(super) fn theme_id(theme: &Value) -> Result<&str, String> {
    super::theme_validation::validate(theme)
}
#[tauri::command]
pub fn portable_preferences(app: tauri::AppHandle, legacy: Option<Value>) -> Result<Value, String> {
    let config = get(&app);
    let mut legacy = legacy.unwrap_or(json!({}));
    if let Some(object) = legacy.as_object_mut() {
        object.remove("error");
    }
    config.migrate("settings.json", "interface", legacy, json!({}))?;
    finish_frontend_migration(&config)?;
    let value = config.read("settings.json", "interface", json!({}))?;
    validate_interface(&value)?;
    Ok(value)
}
#[tauri::command]
pub fn set_portable_preference(
    app: tauri::AppHandle,
    name: String,
    value: Value,
) -> Result<Value, String> {
    validate_preference(&name, &value)?;
    let config = get(&app);
    config.update("settings.json", |doc| {
        if doc.get("interface").is_none() {
            doc["interface"] = json!({});
        }
        validate_interface(&doc["interface"])?;
        doc["interface"][&name] = value;
        Ok(())
    })?;
    let _ = app.emit("portable-config-changed", ());
    let value = config.read("settings.json", "interface", json!({}))?;
    validate_interface(&value)?;
    Ok(value)
}
#[tauri::command]
pub fn portable_themes(app: tauri::AppHandle, legacy: Option<Value>) -> Result<Value, String> {
    let config = get(&app);
    let _guard = WRITES.lock().map_err(|e| e.to_string())?;
    let directory = config.root.join("themes");
    if !config.themes_initialized.load(Ordering::Relaxed) && !directory.exists() {
        let stage = config.root.join(".themes-migration");
        files::directory(&stage)?;
        if config.import_legacy {
            if let Some(themes) = legacy.as_ref().and_then(|v| v["custom"].as_array()) {
                for theme in themes {
                    let id = theme_id(theme)?;
                    let path = stage.join(format!("{id}.json"));
                    let before = files::read(&path)?;
                    files::write(&path, theme, before.as_deref())?;
                }
            }
        }
        std::fs::rename(stage, &directory).map_err(|e| e.to_string())?;
        config.refresh_group("themes");
    }
    config.themes_initialized.store(true, Ordering::Relaxed);
    drop(_guard);
    config.migrate("settings.json", "appearance", json!({"selected":legacy.as_ref().and_then(|v| v["selected"].as_str()).unwrap_or("graphite")}), json!({"selected":"graphite"}))?;
    let mut custom = Vec::new();
    for path in config.entries(&directory)? {
        let theme = config
            .json(&path)?
            .ok_or("Theme disappeared during reload")?;
        let id = theme_id(&theme)?;
        if path.file_stem().and_then(|s| s.to_str()) != Some(id) {
            return Err(format!(
                "Theme filename must match its id: {}",
                path.display()
            ));
        }
        custom.push(theme);
    }
    if custom.len() > 50 {
        return Err("This version supports up to 50 custom themes.".into());
    }
    let appearance: Value = config.read(
        "settings.json",
        "appearance",
        json!({"selected":"graphite"}),
    )?;
    finish_frontend_migration(&config)?;
    Ok(json!({"selected":appearance["selected"], "custom":custom}))
}
#[tauri::command]
pub fn select_portable_theme(app: tauri::AppHandle, id: String) -> Result<(), String> {
    files::safe_id(&id)?;
    save(&app, "appearance", &json!({"selected":id}))?;
    let _ = app.emit("portable-config-changed", ());
    Ok(())
}
#[tauri::command]
pub fn write_portable_theme(
    app: tauri::AppHandle,
    id: String,
    theme: Option<Value>,
    expected: Option<Value>,
) -> Result<(), String> {
    files::safe_id(&id)?;
    let _guard = WRITES.lock().map_err(|e| e.to_string())?;
    let config = get(&app);
    let path = config.root.join("themes").join(format!("{id}.json"));
    let bytes = config.bytes(&path)?;
    let current = bytes
        .as_ref()
        .map(|v| serde_json::from_slice::<Value>(v))
        .transpose()
        .map_err(|e| e.to_string())?;
    if current != expected {
        return Err("This theme changed on disk. Reopen it before saving.".into());
    }
    match theme {
        Some(theme) => {
            if theme_id(&theme)? != id {
                return Err("Theme identifier cannot change during editing.".into());
            }
            config.write_file(&path, &theme, bytes.as_deref())?;
        }
        None => {
            config.remove_file(&path, bytes.as_deref())?;
        }
    }
    let _ = app.emit("portable-config-changed", ());
    Ok(())
}

fn validate_preference(name: &str, value: &Value) -> Result<(), String> {
    if ![
        "notesFont",
        "notesToolbar",
        "notesKeepOnTop",
        "compactLauncher",
        "groupByDate",
        "rememberPosition",
    ]
    .contains(&name)
    {
        return Err("Unknown interface setting".into());
    }
    if name == "notesFont" {
        if !["system", "sans", "serif", "mono"].contains(&value.as_str().unwrap_or_default()) {
            return Err("Invalid font".into());
        }
    } else if !value.is_boolean() {
        return Err("Expected a boolean setting".into());
    }
    Ok(())
}

pub(super) fn validate_interface(value: &Value) -> Result<(), String> {
    let values = value
        .as_object()
        .ok_or("settings.json/interface must be an object")?;
    for (name, value) in values {
        validate_preference(name, value)?;
    }
    Ok(())
}
