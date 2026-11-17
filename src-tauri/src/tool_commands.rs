//! Tool commands share their registry and assignments with the settings UI.
use serde::{Deserialize, Serialize};
use std::sync::OnceLock;
use tauri::{Emitter, Manager};

#[derive(Deserialize)]
pub struct Command {
    pub id: String,
    pub tool: String,
    pub capability: Option<String>,
}
pub fn registry() -> &'static [Command] {
    static COMMANDS: OnceLock<Vec<Command>> = OnceLock::new();
    COMMANDS.get_or_init(|| {
        serde_json::from_str(include_str!("../../src/features/shortcuts/commands.json"))
            .expect("valid command registry")
    })
}
pub fn find(id: &str) -> Option<&'static Command> {
    registry().iter().find(|command| command.id == id)
}
#[derive(Serialize)]
pub struct Availability {
    pub available: bool,
    pub reason: Option<String>,
}
pub fn unavailable_reason(app: &tauri::AppHandle, id: &str) -> Option<String> {
    let command = find(id)?;
    if command.tool == "shelf" {
        return crate::extensions::shelferry::status(app).reason;
    }
    let capability = command.capability.as_deref()?;
    (!crate::system_actions::platform::supports(capability, std::env::consts::OS))
        .then(|| "Not supported on this platform yet.".into())
}
#[tauri::command]
pub fn command_availability(
    app: tauri::AppHandle,
) -> std::collections::BTreeMap<String, Availability> {
    registry()
        .iter()
        .map(|command| {
            let reason = unavailable_reason(&app, &command.id);
            (
                command.id.clone(),
                Availability {
                    available: reason.is_none(),
                    reason,
                },
            )
        })
        .collect()
}
pub fn enabled(app: &tauri::AppHandle, id: &str) -> bool {
    if unavailable_reason(app, id).is_some() {
        return false;
    }
    true
}
#[tauri::command]
pub async fn execute_tool_command(app: tauri::AppHandle, id: String) -> Result<(), String> {
    if find(&id).is_none() {
        return Err("Unknown tool command.".into());
    }
    if let Some(reason) = unavailable_reason(&app, &id) {
        return Err(reason);
    }
    if !enabled(&app, &id) {
        return Err("Enable this tool in Settings first.".into());
    }
    let target = match id.as_str() {
        "command:systemMonitor.open" => Some(("main", crate::launcher_presentation::active_view(&app) == "systemMonitor")),
        "command:notes.open" => Some(("notes", true)),
        "command:keepAwake.open" => Some((
            "main",
            crate::launcher_presentation::active_view(&app) == "keepAwake",
        )),
        "command:system.open" => Some((
            "main",
            crate::launcher_presentation::active_view(&app) == "system",
        )),
        "command:emoji.open" => Some((
            "main",
            crate::launcher_presentation::active_view(&app) == "emoji",
        )),
        "command:snippets.open" => Some((
            "main",
            crate::launcher_presentation::active_view(&app) == "snippets",
        )),
        "command:clipboard.open" => Some((
            "main",
            crate::launcher_presentation::active_view(&app) == "clipboard",
        )),
        _ => None,
    };
    if let Some((label, same_view)) = target {
        if label == "main" && crate::launcher_presentation::cancel_tool(&app, &id) {
            return Ok(());
        }
        if let Some(window) = app.get_webview_window(label) {
            if crate::window_toggle::should_hide(&app, &window, same_view)
                .map_err(|e| e.to_string())?
            {
                crate::window_toggle::dismiss_popups(&app, label);
                if label == "notes" {
                    // Preserve save-before-hide. Failed saves leave the editor visible.
                    return window.emit("notes-close", ()).map_err(|e| e.to_string());
                }
                return crate::launcher_presentation::dismiss_launcher(app.clone());
            }
        }
    }
    match id.as_str() {
        id if id.starts_with("command:system.keepAwake") => {
            crate::keep_awake::execute(&app, id)?;
        }
        "command:system.sleep" | "command:system.emptyTrash" => {
            crate::system_actions::execute(app, id).await?;
        }
        "command:systemMonitor.open" | "command:system.open" | "command:system.eject" | "command:keepAwake.open" => {
            crate::launcher_presentation::request_tool(&app, &id).map_err(|e| e.to_string())?;
        }
        "command:notes.open" | "command:notes.new" | "command:notes.browse" => {
            *app.state::<crate::notes::Notes>()
                .2
                .lock()
                .map_err(|e| e.to_string())? = id.ends_with(".browse");
            crate::notes::open_notes(app.clone(), None, id.ends_with(".new")).await?;
            crate::launcher_presentation::dismiss_launcher(app.clone())?;
        }
        "command:shelf.open"
        | "command:shelf.new"
        | "command:shelf.toggle"
        | "command:shelf.settings" => {
            crate::extensions::shelferry::execute(&app, &id).await?;
        }
        "command:snippets.open" => {
            crate::snippets::open(&app).await?;
        }
        "command:emoji.open"
        | "command:clipboard.open"
        | "command:clipboard.pinned"
        | "command:clipboard.links" => {
            crate::launcher_presentation::request_tool(&app, &id).map_err(|e| e.to_string())?
        }
        _ => return Err("Command has no handler.".into()),
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn command_ids_are_unique_and_scoped() {
        let mut ids = std::collections::HashSet::new();
        for command in registry() {
            assert!(ids.insert(&command.id));
            // Keep existing wake-lock IDs so saved aliases and shortcuts survive the tool move.
            assert!(
                command
                    .id
                    .starts_with(&format!("command:{}.", command.tool))
                    || (command.tool == "keepAwake"
                        && command.id.starts_with("command:system.keepAwake"))
            );
        }
        assert!(find("command:unknown").is_none());
    }
}
