use super::*;
use std::collections::BTreeMap;
use tauri_plugin_global_shortcut::Shortcut;

pub fn group(config: &Config, name: &str) -> Result<String, String> {
    match name {
        "settings.json" => {
            config.document(name)?;
            for key in ["hyperEnabled", "swiftSnippetsImported"] {
                config.read::<bool>(name, key, false)?;
            }
            frontend::validate_interface(&config.read(name, "interface", json!({}))?)?;
            crate::general_settings::validate_configuration(config)?;
            crate::clipboard::preferences::validate_configuration(config)?;
            crate::keep_awake::validate_configuration(config)?;
            crate::snippets::validate_preferences(config)?;
            let appearance = config.read(name, "appearance", json!({"selected":"graphite"}))?;
            files::safe_id(
                appearance["selected"]
                    .as_str()
                    .ok_or("appearance/selected must be a theme identifier")?,
            )?;
            Ok("Preferences loaded".into())
        }
        "shortcuts.json" => {
            config.document(name)?;
            config
                .read(name, "launcher", "CommandOrControl+Space".to_string())?
                .parse::<Shortcut>()
                .map_err(|e| format!("Launcher shortcut: {e}"))?;
            let assignments: BTreeMap<String, crate::applications::preferences::Preference> =
                config.read(name, "assignments", BTreeMap::new())?;
            for (key, value) in &assignments {
                if value.alias.len() > 80 {
                    return Err(format!("{key}: alias exceeds 80 characters"));
                }
                if !value.shortcut.is_empty() {
                    value
                        .shortcut
                        .parse::<Shortcut>()
                        .map_err(|e| format!("{key}: {e}"))?;
                }
            }
            Ok(format!("{} assignments loaded", assignments.len()))
        }
        "themes" => {
            let paths = config.entries(&config.root.join(name))?;
            if paths.len() > 50 {
                return Err("This version supports up to 50 custom themes.".into());
            }
            for path in &paths {
                let theme = config.json(path)?.ok_or("Theme file is missing")?;
                let id = frontend::theme_id(&theme)?;
                if path.file_stem().and_then(|s| s.to_str()) != Some(id) {
                    return Err(format!(
                        "Theme filename must match its id: {}",
                        path.display()
                    ));
                }
            }
            Ok(format!("{} custom themes loaded", paths.len()))
        }
        "snippets" => {
            crate::snippets::validate_configuration(config).map(|n| format!("{n} snippets loaded"))
        }
        _ => Err("Unknown configuration category".into()),
    }
}
