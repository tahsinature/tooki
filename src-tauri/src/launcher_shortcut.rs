use std::{
    fs,
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex,
    },
};
use tauri::{AppHandle, Emitter, Manager, State};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};

const DEFAULT: &str = "CommandOrControl+Space";
#[derive(Default)]
pub struct LauncherShortcut {
    active: Mutex<Option<String>>,
    recording: AtomicBool,
}

impl LauncherShortcut {
    pub fn is_recording(&self) -> bool {
        self.recording.load(Ordering::Relaxed)
    }
    pub fn stop_recording(&self) {
        self.recording.store(false, Ordering::Relaxed);
    }
}

fn register_key(app: &AppHandle, value: &str) -> Result<(), String> {
    if app.global_shortcut().is_registered(value) {
        return Err("This shortcut is already assigned in Tooki.".into());
    }
    app.global_shortcut()
        .on_shortcut(value, |app, _, event| {
            if event.state == ShortcutState::Pressed
                && !app
                    .state::<LauncherShortcut>()
                    .recording
                    .load(Ordering::Relaxed)
            {
                if let Err(error) = toggle(app) {
                    eprintln!("Could not toggle launcher: {error}");
                }
            }
        })
        .map_err(|e| format!("Could not register shortcut. It may be used by another app: {e}"))
}

fn save(app: &AppHandle, value: &str) -> Result<(), String> {
    let directory = app.path().app_config_dir().map_err(|e| e.to_string())?;
    fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
    let temporary = directory.join("launcher-shortcut.tmp");
    fs::write(&temporary, value).map_err(|e| e.to_string())?;
    fs::rename(temporary, directory.join("launcher-shortcut.txt")).map_err(|e| e.to_string())
}

pub fn register(app: &AppHandle) {
    let saved = app
        .path()
        .app_config_dir()
        .ok()
        .and_then(|dir| fs::read_to_string(dir.join("launcher-shortcut.txt")).ok());
    let value = saved.as_deref().unwrap_or(DEFAULT).trim();
    match register_key(app, value) {
        Ok(()) => *app.state::<LauncherShortcut>().active.lock().unwrap() = Some(value.into()),
        Err(error) => eprintln!("{error}"),
    }
}

#[tauri::command]
pub fn get_launcher_shortcut(state: State<LauncherShortcut>) -> Result<String, String> {
    state
        .active
        .lock()
        .map_err(|e| e.to_string())?
        .clone()
        .ok_or_else(|| "No launcher shortcut is active. Record a new shortcut.".into())
}

#[tauri::command]
pub fn set_shortcut_recording(state: State<LauncherShortcut>, recording: bool) {
    state.recording.store(recording, Ordering::Relaxed);
}

#[tauri::command]
pub fn set_launcher_shortcut(
    app: AppHandle,
    state: State<LauncherShortcut>,
    shortcut: String,
) -> Result<String, String> {
    let parsed: Shortcut = shortcut
        .parse()
        .map_err(|e| format!("Invalid shortcut: {e}"))?;
    let mut active = state.active.lock().map_err(|e| e.to_string())?;
    if active.as_deref().and_then(|v| v.parse::<Shortcut>().ok()) == Some(parsed) {
        return Ok(active.clone().unwrap());
    }
    register_key(&app, &shortcut)?;
    // Register the replacement first so a conflict never disables the old shortcut.
    if let Err(error) = save(&app, &shortcut) {
        let _ = app.global_shortcut().unregister(shortcut.as_str());
        return Err(format!("Could not save shortcut: {error}"));
    }
    if let Some(previous) = active.as_deref() {
        if let Err(error) = app.global_shortcut().unregister(previous) {
            let _ = app.global_shortcut().unregister(shortcut.as_str());
            let _ = save(&app, previous);
            return Err(format!("Could not replace the previous shortcut: {error}"));
        }
    }
    *active = Some(shortcut.clone());
    let _ = app.emit("launcher-shortcut-changed", &shortcut);
    Ok(shortcut)
}

fn toggle(app: &AppHandle) -> tauri::Result<()> {
    let Some(window) = app.get_webview_window("main") else {
        return Ok(());
    };
    if crate::launcher_presentation::cancel(app) {
        return Ok(());
    }
    let hide = crate::window_toggle::should_hide(app, &window, true)?;
    crate::window_toggle::dismiss_popups(app, "main");
    if hide {
        crate::launcher_presentation::dismiss(app)?;
    } else {
        let _ = crate::clipboard::native::call("rememberTarget", serde_json::json!({}));
        crate::launcher_presentation::request(app)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn recorder_keys_are_supported_by_native_parser() {
        for key in [
            "KeyK",
            "Digit2",
            "Space",
            "Comma",
            "ArrowUp",
            "F24",
            "BracketLeft",
            "PageDown",
        ] {
            assert!(
                format!("Super+Shift+{key}").parse::<Shortcut>().is_ok(),
                "{key}"
            );
        }
        assert!(DEFAULT.parse::<Shortcut>().is_ok());
    }
}
