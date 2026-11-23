//! OS integration boundary. Features own data and workflows; adapters own OS calls.
pub mod system_monitor;
pub mod launcher;
pub mod preview;
pub mod shelf;
pub mod window_chrome;
use serde::Serialize;
use serde_json::{json, Value};
use std::path::Path;
use tauri::AppHandle;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileCapabilities {
    pub native_preview: bool,
    pub open_with: bool,
    pub copy_files: bool,
}
pub fn file_capabilities() -> FileCapabilities {
    FileCapabilities {
        native_preview: cfg!(target_os = "macos"),
        open_with: cfg!(target_os = "macos"),
        copy_files: cfg!(target_os = "macos"),
    }
}
pub fn file_action(
    app: &AppHandle,
    operation: &str,
    path: &Path,
    application: Option<&str>,
) -> Result<Value, String> {
    if !path.exists() {
        return Err("This file is no longer available.".into());
    }
    #[cfg(target_os = "macos")]
    {
        let mut payload = json!({"path":path,"paths":[path]});
        if operation == "copyFile" {
            return crate::clipboard::native::on_main(
                app,
                "copy",
                json!({"item":{"files":[path]}}),
            );
        }
        if let Some(application) = application {
            let apps = crate::clipboard::native::on_main(app, "apps", payload.clone())?;
            if !apps.as_array().is_some_and(|apps| {
                apps.iter()
                    .any(|entry| entry["path"].as_str() == Some(application))
            }) {
                return Err("Choose an application from Open With.".into());
            }
            payload["app"] = json!(application);
        }
        if operation == "reveal" {
            return std::process::Command::new("/usr/bin/open")
                .arg("-R")
                .arg(path)
                .spawn()
                .map(|_| Value::Null)
                .map_err(|e| e.to_string());
        }
        return crate::clipboard::native::on_main(app, operation, payload);
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (app, application);
        if !matches!(operation, "open" | "reveal") {
            return Err("This native action is not available on this platform yet.".into());
        }
        #[cfg(target_os = "windows")]
        let mut command = std::process::Command::new("explorer.exe");
        #[cfg(target_os = "linux")]
        let mut command = std::process::Command::new("xdg-open");
        let target = if operation == "reveal" {
            path.parent().unwrap_or(path)
        } else {
            path
        };
        command
            .arg(target)
            .spawn()
            .map(|_| json!(null))
            .map_err(|e| e.to_string())
    }
}

pub mod menu_bar_icon;

pub mod toast;

pub mod root_search_shortcut;

pub mod windows;

#[cfg(target_os = "macos")]
pub mod panels;
