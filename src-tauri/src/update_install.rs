use serde::Serialize;
use std::{
    path::Path,
    sync::Mutex,
    time::{Duration, Instant},
};
use tauri::{Emitter, Manager};
use tauri_plugin_updater::UpdaterExt;

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstallStatus {
    phase: Phase,
    downloaded: u64,
    total: Option<u64>,
    error: Option<String>,
}

#[derive(Clone, Copy, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
enum Phase {
    #[default]
    Idle,
    Checking,
    Downloading,
    Verifying,
    Installing,
    Restarting,
    Failed,
}

#[derive(Default)]
pub struct Installer(Mutex<InstallStatus>);

fn install_policy(
    platform: &str,
    debug: bool,
    identifier: &str,
    executable: &Path,
) -> Result<(), String> {
    if debug || identifier != "us.tahsin.tooki" {
        return Err(
            "Development builds check releases but never install production updates.".into(),
        );
    }
    if platform != "macos" {
        return Err("In-app updates are currently available on macOS.".into());
    }
    if !executable.ends_with("Tooki.app/Contents/MacOS/tooki") || executable.starts_with("/Volumes")
    {
        return Err("Move Tooki to Applications and reopen it to install updates.".into());
    }
    Ok(())
}

pub fn ensure_supported(app: &tauri::AppHandle) -> Result<(), String> {
    let executable = std::env::current_exe().map_err(|_| "Could not locate the running app.")?;
    install_policy(
        std::env::consts::OS,
        cfg!(debug_assertions),
        &app.config().identifier,
        &executable,
    )
}

fn publish(app: &tauri::AppHandle, status: InstallStatus) {
    *app.state::<Installer>().0.lock().unwrap() = status.clone();
    let _ = app.emit_to("settings", "update-install-status", status);
}

#[tauri::command]
pub fn update_install_status(app: tauri::AppHandle) -> InstallStatus {
    app.state::<Installer>().0.lock().unwrap().clone()
}

// No URLs, paths or signing keys come from the webview. The version is pinned to
// what the user chose; a newly published release cannot silently change it.
#[tauri::command]
pub fn install_update(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    version: String,
) -> Result<(), String> {
    if window.label() != "settings" {
        return Err("Open Settings to install updates.".into());
    }
    ensure_supported(&app)?;
    validate_version(&version, &app.package_info().version)?;
    {
        let installer = app.state::<Installer>();
        let mut status = installer.0.lock().unwrap();
        if !matches!(status.phase, Phase::Idle | Phase::Failed) {
            return Err("An update is already in progress.".into());
        }
        *status = InstallStatus {
            phase: Phase::Checking,
            ..Default::default()
        };
    }
    publish(&app, update_install_status(app.clone()));
    tauri::async_runtime::spawn(async move {
        if let Err(error) = run_install(&app, &version).await {
            publish(
                &app,
                InstallStatus {
                    phase: Phase::Failed,
                    error: Some(error),
                    ..Default::default()
                },
            );
        }
    });
    Ok(())
}

fn validate_version(version: &str, current: &semver::Version) -> Result<(), String> {
    let version = semver::Version::parse(version).map_err(|_| "Invalid update version.")?;
    if !version.pre.is_empty() || !version.build.is_empty() || version <= *current {
        return Err("Only a newer stable release can be installed.".into());
    }
    Ok(())
}

fn validate_package(actual_version: &str, url: &str, expected_version: &str) -> Result<(), String> {
    let expected_url = format!("https://github.com/tahsinature/tooki/releases/download/v{expected_version}/Tooki.app.tar.gz");
    if actual_version != expected_version || url != expected_url {
        return Err("The update package does not match the selected release.".into());
    }
    Ok(())
}

async fn run_install(app: &tauri::AppHandle, version: &str) -> Result<(), String> {
    let base = format!("https://github.com/tahsinature/tooki/releases/download/v{version}");
    let updater = app
        .updater_builder()
        .endpoints(vec![format!("{base}/latest.json").parse().unwrap()])
        .map_err(|e| e.to_string())?
        .timeout(Duration::from_secs(30))
        .build()
        .map_err(|e| e.to_string())?;
    let mut update = updater
        .check()
        .await
        .map_err(|e| format!("Could not check the signed update: {e}"))?
        .ok_or("This update is no longer available. Check for updates again.")?;
    validate_package(&update.version, update.download_url.as_str(), version)?;
    update.timeout = Some(Duration::from_secs(600));
    let mut downloaded = 0;
    let mut reported_at = Instant::now();
    let bytes = update
        .download(
            |chunk, total| {
                downloaded += chunk as u64;
                // Report at most ten times a second, rather than flooding the webview.
                if downloaded != chunk as u64 && reported_at.elapsed() < Duration::from_millis(100)
                {
                    return;
                }
                reported_at = Instant::now();
                publish(
                    app,
                    InstallStatus {
                        phase: Phase::Downloading,
                        downloaded,
                        total,
                        error: None,
                    },
                );
            },
            || {
                publish(
                    app,
                    InstallStatus {
                        phase: Phase::Verifying,
                        ..Default::default()
                    },
                );
            },
        )
        .await
        .map_err(|e| format!("Could not download or verify the update: {e}"))?;
    publish(
        app,
        InstallStatus {
            phase: Phase::Installing,
            ..Default::default()
        },
    );
    // Archive extraction and bundle replacement must not block the UI/runtime.
    tauri::async_runtime::spawn_blocking(move || update.install(bytes))
        .await
        .map_err(|e| format!("The installer stopped: {e}"))?
        .map_err(|e| format!("Could not install the update: {e}"))?;
    publish(
        app,
        InstallStatus {
            phase: Phase::Restarting,
            ..Default::default()
        },
    );
    // Delivers ExitRequested and Exit so all existing save/cleanup hooks run.
    app.request_restart();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn only_packaged_production_macos_can_install() {
        let installed = Path::new("/Applications/Tooki.app/Contents/MacOS/tooki");
        assert!(install_policy("macos", false, "us.tahsin.tooki", installed).is_ok());
        for (platform, debug, id, path) in [
            ("macos", true, "us.tahsin.tooki", installed),
            ("macos", false, "us.tahsin.tooki.dev", installed),
            ("linux", false, "us.tahsin.tooki", installed),
            ("windows", false, "us.tahsin.tooki", installed),
            ("macos", false, "us.tahsin.tooki", Path::new("/tmp/tooki")),
            (
                "macos",
                false,
                "us.tahsin.tooki",
                Path::new("/Volumes/Tooki/Tooki.app/Contents/MacOS/tooki"),
            ),
        ] {
            assert!(install_policy(platform, debug, id, path).is_err());
        }
    }
    #[test]
    fn manifest_must_match_the_selected_release_and_official_asset() {
        let url = "https://github.com/tahsinature/tooki/releases/download/v1.2.4/Tooki.app.tar.gz";
        assert!(validate_package("1.2.4", url, "1.2.4").is_ok());
        assert!(validate_package("1.2.5", url, "1.2.4").is_err());
        for other in [
            "http://github.com/tahsinature/tooki/releases/download/v1.2.4/Tooki.app.tar.gz",
            "https://example.com/Tooki.app.tar.gz",
            "file:///tmp/Tooki.app.tar.gz",
        ] {
            assert!(validate_package("1.2.4", other, "1.2.4").is_err());
        }
    }
    #[test]
    fn refuses_downgrades_prereleases_and_untrusted_version_paths() {
        let current = semver::Version::parse("1.2.3").unwrap();
        assert!(validate_version("1.2.4", &current).is_ok());
        for value in [
            "1.2.3",
            "1.0.0",
            "2.0.0-beta.1",
            "2.0.0+dev",
            "../latest",
            "v2.0.0",
        ] {
            assert!(validate_version(value, &current).is_err());
        }
    }
}
