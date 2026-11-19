mod adapter;
mod status;
use status::Status;
use std::{fs, path::PathBuf, sync::Mutex};
use tauri::{Emitter, Manager};
use tauri_plugin_dialog::DialogExt;
#[derive(Default)]
pub struct Hyper(Mutex<Status>);
fn directory(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let path = app
        .path()
        .app_config_dir()
        .map_err(|e| e.to_string())?
        .join("hyper");
    fs::create_dir_all(&path).map_err(|e| e.to_string())?;
    Ok(path)
}
// Native macOS event taps and their teardown must run on the AppKit main thread.
fn apply(app: &tauri::AppHandle, enabled: bool) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    let recovery = {
        let directory = app
            .path()
            .home_dir()
            .map_err(|e| e.to_string())?
            .join("Library/Application Support/us.tahsin.tooki.shared/hyper");
        crate::config::files::directory(&directory)?;
        directory.join("mapping-recovery.json")
    };
    #[cfg(not(target_os = "macos"))]
    let recovery = directory(app)?.join("mapping-recovery.json");
    adapter::set(enabled, &recovery)
}
pub fn initialize(app: &tauri::AppHandle) {
    let mut state = Status {
        available: cfg!(any(target_os = "macos", target_os = "windows")),
        helper_required: cfg!(target_os = "linux"),
        permission_required: crate::permissions::required(),
        ..Default::default()
    };
    match (|| -> Result<bool, String> {
        let config = crate::config::get(app);
        config.migrate(
            "settings.json",
            "hyperEnabled",
            directory(app)?.join("enabled").exists(),
            false,
        )?;
        crate::config::read(app, "hyperEnabled")
    })() {
        Ok(enabled) => {
            state.enabled = enabled;
            state.apply(
                |enabled| {
                    apply(app, false)?;
                    if enabled {
                        apply(app, true)?;
                    }
                    Ok(())
                },
                adapter::active,
            );
        }
        Err(error) => state.error = error,
    }
    *app.state::<Hyper>().0.lock().unwrap() = state;
}
pub fn stop(app: &tauri::AppHandle) {
    if let Err(error) = apply(app, false) {
        eprintln!("Could not restore Hyper Key: {error}");
    }
}
#[tauri::command]
pub async fn hyper_request(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    operation: String,
    enabled: Option<bool>,
) -> Result<Status, String> {
    if window.label() != "settings" {
        return Err("Hyper Key can only be configured in Settings.".into());
    }
    if operation == "exportHelper" {
        let app_copy = app.clone();
        tauri::async_runtime::spawn_blocking(move || -> Result<(), String> {
            let Some(file) = app_copy
                .dialog()
                .file()
                .set_file_name("tooki-hyper.conf")
                .blocking_save_file()
            else {
                return Ok(());
            };
            fs::write(
                file.into_path().map_err(|e| e.to_string())?,
                hyper_key::KEYD_CONFIG,
            )
            .map_err(|e| e.to_string())
        })
        .await
        .map_err(|e| e.to_string())??;
    } else if !matches!(
        operation.as_str(),
        "set" | "retry" | "status" | "openPermissions" | "recheck"
    ) {
        return Err("Unknown Hyper Key operation".into());
    }
    if operation == "set" && enabled.is_none() {
        return Err("Choose whether Hyper Key is enabled".into());
    }
    crate::permissions::request(
        &app,
        if operation == "openPermissions" {
            "open"
        } else {
            "status"
        },
    )
    .await?;
    // Status reads also run on the main thread, where macOS owns the event tap.
    let (tx, rx) = std::sync::mpsc::sync_channel(1);
    let handle = app.clone();
    app.run_on_main_thread(move || {
        let result = (|| {
            let hyper = handle.state::<Hyper>();
            let mut state = hyper.0.lock().map_err(|e| e.to_string())?;
            if operation == "set" {
                let enabled = enabled.unwrap();
                crate::config::save(&handle, "hyperEnabled", &enabled)?;
                state.enabled = enabled;
            }
            state.permission_required = crate::permissions::required();
            if operation == "set" || operation == "retry" {
                state.apply(
                    |enabled| {
                        if operation == "retry" {
                            apply(&handle, false)?;
                        }
                        apply(&handle, enabled)
                    },
                    adapter::active,
                );
            } else {
                state.refresh(adapter::active());
            }
            Ok::<_, String>(state.clone())
        })();
        if matches!(operation.as_str(), "set" | "retry") {
            let _ = handle.emit("hyper-changed", ());
        }
        let _ = tx.send(result);
    })
    .map_err(|e| e.to_string())?;
    tauri::async_runtime::spawn_blocking(move || rx.recv())
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())?
}

pub fn reload_preferences(app: &tauri::AppHandle) -> Result<(), String> {
    let enabled: bool = crate::config::read(app, "hyperEnabled")?;
    let state = app.state::<Hyper>();
    let mut current = state.0.lock().map_err(|e| e.to_string())?;
    if current.enabled != enabled {
        current.enabled = enabled;
        current.permission_required = crate::permissions::required();
        current.apply(|enabled| apply(app, enabled), adapter::active);
        let _ = app.emit("hyper-changed", ());
    }
    if !current.error.is_empty() {
        return Err(current.error.clone());
    }
    Ok(())
}

/// Called on the main thread when the shared Accessibility grant changes.
pub fn permission_changed(app: &tauri::AppHandle) {
    let state = app.state::<Hyper>();
    let mut current = state.0.lock().unwrap();
    current.permission_required = crate::permissions::required();
    let should_run = current.enabled && !current.permission_required;
    current.error = apply(app, should_run).err().unwrap_or_default();
    current.refresh(adapter::active());
    let _ = app.emit("hyper-changed", ());
}
