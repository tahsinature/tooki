use semver::Version;
use serde::{Deserialize, Serialize};
use std::{cmp::Ordering, time::Duration};

const ENDPOINT: &str = "https://api.github.com/repos/tahsinature/tooki/releases/latest";
const UPDATE_COMMAND: &str = "brew update && brew upgrade --cask tahsinature/tap/tooki";
const MAX_RESPONSE: usize = 1024 * 1024;

#[derive(Deserialize)]
struct Release {
    tag_name: String,
    draft: bool,
    prerelease: bool,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UpdateCheck {
    latest_version: String,
    status: &'static str,
    release_tag: String,
    update_command: Option<&'static str>,
}

fn parse_release(status: u16, body: &[u8], current: &Version) -> Result<UpdateCheck, String> {
    match status {
        200 => {}
        403 | 429 => {
            return Err("GitHub’s request limit was reached. Please try again later.".into())
        }
        404 => return Err("No published release was found. Please try again later.".into()),
        _ => {
            return Err(format!(
                "The update service returned HTTP {status}. Please try again later."
            ))
        }
    }
    let release: Release = serde_json::from_slice(body)
        .map_err(|_| "The update service returned an invalid release.".to_string())?;
    let latest = release_version(&release.tag_name)?;
    if release.draft || release.prerelease || !latest.pre.is_empty() {
        return Err("The update service did not return a stable release.".into());
    }
    Ok(UpdateCheck {
        latest_version: latest.to_string(),
        status: match latest.cmp_precedence(current) {
            Ordering::Greater => "available",
            Ordering::Equal => "current",
            Ordering::Less => "ahead",
        },
        release_tag: release.tag_name,
        update_command: cfg!(target_os = "macos").then_some(UPDATE_COMMAND),
    })
}

fn release_version(tag: &str) -> Result<Version, String> {
    Version::parse(tag.strip_prefix('v').unwrap_or(tag))
        .map_err(|_| "The release has an unrecognized version number.".into())
}

#[tauri::command]
pub async fn check_for_updates(app: tauri::AppHandle) -> Result<UpdateCheck, String> {
    let client = reqwest::Client::builder()
        .user_agent(concat!("Tooki/", env!("CARGO_PKG_VERSION")))
        .timeout(Duration::from_secs(15))
        .connect_timeout(Duration::from_secs(5))
        .https_only(true)
        .build()
        .map_err(|_| "Could not initialize the update check.".to_string())?;
    let mut response = client
        .get(ENDPOINT)
        .header("Accept", "application/vnd.github+json")
        .send()
        .await
        .map_err(network_error)?;
    let status = response.status().as_u16();
    let mut body = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(network_error)? {
        if body.len() + chunk.len() > MAX_RESPONSE {
            return Err("The update service returned an unexpectedly large response.".into());
        }
        body.extend_from_slice(&chunk);
    }
    parse_release(status, &body, &app.package_info().version)
}

fn network_error(error: reqwest::Error) -> String {
    if error.is_timeout() {
        "The update check timed out. Please try again.".into()
    } else {
        "Could not reach GitHub. Check your connection and try again.".into()
    }
}

#[tauri::command]
pub async fn open_release_notes(tag: String) -> Result<(), String> {
    // Build a fixed-origin URL from a validated version, never an arbitrary URL or command.
    release_version(&tag)?;
    let url = format!("https://github.com/tahsinature/tooki/releases/tag/{tag}");
    #[cfg(target_os = "macos")]
    let mut command = tokio::process::Command::new("/usr/bin/open");
    #[cfg(target_os = "linux")]
    let mut command = tokio::process::Command::new("xdg-open");
    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = tokio::process::Command::new("rundll32.exe");
        command.arg("url.dll,FileProtocolHandler");
        command
    };
    command.arg(url).kill_on_drop(true);
    let status = tokio::time::timeout(Duration::from_secs(10), command.status())
        .await
        .map_err(|_| "Opening release notes timed out.".to_string())?
        .map_err(|e| format!("Could not open release notes: {e}"))?;
    if !status.success() {
        return Err("Could not open release notes in your browser.".into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn check(tag: &str, current: &str) -> UpdateCheck {
        let body = serde_json::json!({"tag_name":tag,"draft":false,"prerelease":false});
        parse_release(
            200,
            &serde_json::to_vec(&body).unwrap(),
            &Version::parse(current).unwrap(),
        )
        .unwrap()
    }
    #[test]
    fn compares_versions_numerically_and_handles_development_builds() {
        assert_eq!(check("v0.12.0", "0.9.0").status, "available");
        assert_eq!(check("v0.12.0", "0.12.0").status, "current");
        assert_eq!(check("v0.12.0", "0.13.0").status, "ahead");
        assert_eq!(check("v0.12.0", "0.12.0-beta.1").status, "available");
        assert_eq!(check("0.12.0", "0.12.0+dev").status, "current");
    }
    #[test]
    fn rejects_failed_requests_and_invalid_or_unstable_releases() {
        let current = Version::parse("0.12.0").unwrap();
        for status in [403, 404, 429, 500] {
            assert!(parse_release(status, b"{}", &current).is_err());
        }
        for body in [
            r#"{"tag_name":"v1.0.0","draft":true,"prerelease":false}"#,
            r#"{"tag_name":"v1.0.0","draft":false,"prerelease":true}"#,
            r#"{"tag_name":"v1.0.0-beta.1","draft":false,"prerelease":false}"#,
            r#"{"tag_name":"not-a-version","draft":false,"prerelease":false}"#,
            "broken",
            "{}",
        ] {
            assert!(parse_release(200, body.as_bytes(), &current).is_err());
        }
        assert!(release_version("../../other").is_err());
    }
}
