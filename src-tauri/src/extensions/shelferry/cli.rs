use serde::Deserialize;
use std::{
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};

pub const INSTALL: &str = "brew install --cask tahsinature/tap/shelferry";

pub fn platform_reason(os: &str, major: Option<u32>) -> Option<String> {
    (os != "macos" || major.is_none_or(|version| version < 14))
        .then(|| "Shelferry requires macOS 14 or later.".into())
}
pub fn operation(id: &str) -> Option<&'static str> {
    match id {
        "command:shelf.open" => Some("manager"),
        "command:shelf.new" => Some("new"),
        "command:shelf.toggle" => Some("toggle"),
        "command:shelf.settings" => Some("settings"),
        _ => None,
    }
}
fn executable(path: &Path) -> bool {
    let Ok(metadata) = path.metadata() else {
        return false;
    };
    if !metadata.is_file() {
        return false;
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        metadata.permissions().mode() & 0o111 != 0
    }
    #[cfg(not(unix))]
    {
        true
    }
}
pub fn discover(
    override_path: &str,
    candidates: impl IntoIterator<Item = PathBuf>,
) -> Result<PathBuf, String> {
    if !override_path.is_empty() {
        let path = PathBuf::from(override_path);
        return if path.is_absolute() && executable(&path) {
            Ok(path)
        } else {
            Err(
                "Choose an absolute path to an executable Shelferry CLI, or clear the override."
                    .into(),
            )
        };
    }
    candidates
        .into_iter()
        .find(|path| executable(path))
        .ok_or_else(|| format!("Shelferry is not installed. Run: {INSTALL}"))
}
#[derive(Deserialize)]
struct Reply {
    version: u32,
    shelves: Vec<serde_json::Value>,
    items: Vec<serde_json::Value>,
    error: Option<String>,
}
fn decode(success: bool, stdout: &[u8], stderr: &[u8]) -> Result<(), String> {
    let reply: Reply = serde_json::from_slice(stdout).map_err(|_| {
        let diagnostic = String::from_utf8_lossy(stderr)
            .chars()
            .take(500)
            .collect::<String>();
        format!("Shelferry returned an invalid JSON response. {diagnostic}")
    })?;
    if reply.version != 1 {
        return Err(format!(
            "Unsupported Shelferry response version: {}",
            reply.version
        ));
    }
    let _ = (reply.shelves, reply.items);
    if let Some(error) = reply.error {
        return Err(format!("Shelferry: {error}"));
    }
    if !success {
        return Err(format!(
            "Shelferry exited unsuccessfully. {}",
            String::from_utf8_lossy(stderr)
                .chars()
                .take(500)
                .collect::<String>()
        ));
    }
    Ok(())
}
pub async fn run(path: &Path, operation: &str) -> Result<(), String> {
    let output = tokio::process::Command::new(path)
        .args([operation, "--json"])
        .stdin(Stdio::null())
        .kill_on_drop(true)
        .output();
    let output = tokio::time::timeout(Duration::from_secs(135), output).await
        .map_err(|_| "Shelferry timed out. The operation may have completed; check Shelferry before trying again.".to_string())?
        .map_err(|error| format!("Could not start Shelferry: {error}. Install with: {INSTALL}"))?;
    decode(output.status.success(), &output.stdout, &output.stderr)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn routes_preserve_shelferry_toggle_semantics() {
        assert_eq!(operation("command:shelf.open"), Some("manager"));
        assert_eq!(operation("command:shelf.toggle"), Some("toggle"));
        assert_eq!(operation("command:shelf.new"), Some("new"));
        assert_eq!(operation("command:shelf.settings"), Some("settings"));
        assert_eq!(operation("command:shelf.delete"), None);
    }
    #[test]
    fn responses_require_success_and_supported_json() {
        let valid = br#"{"version":1,"shelves":[],"items":[],"future":true}"#;
        assert!(decode(true, valid, b"").is_ok());
        assert!(decode(false, valid, b"failed").is_err());
        assert!(decode(
            true,
            br#"{"version":1,"shelves":[],"items":[],"error":"denied"}"#,
            b""
        )
        .unwrap_err()
        .contains("denied"));
        assert!(decode(true, br#"{"version":2,"shelves":[],"items":[]}"#, b"").is_err());
        assert!(decode(true, b"{}", b"").is_err());
        assert!(decode(true, b"not json", b"").is_err());
    }
    #[test]
    fn unsupported_platforms_and_invalid_overrides_fail_closed() {
        assert!(platform_reason("macos", Some(14)).is_none());
        assert!(platform_reason("macos", Some(13)).is_some());
        assert!(platform_reason("macos", None).is_some());
        assert!(platform_reason("linux", Some(14)).is_some());
        assert!(platform_reason("windows", Some(14)).is_some());
        assert!(discover("relative/shelferry", [PathBuf::from("/bin/sh")]).is_err());
        assert!(discover("/missing/shelferry", [PathBuf::from("/bin/sh")]).is_err());
        assert!(discover("", []).unwrap_err().contains(INSTALL));
    }
    #[cfg(unix)]
    #[tokio::test]
    async fn executable_receives_arguments_without_a_shell() {
        use std::os::unix::fs::PermissionsExt;
        let directory =
            std::env::temp_dir().join(format!("tooki-shelferry-test-{}", std::process::id()));
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join("cli with spaces");
        std::fs::write(&path, "#!/bin/sh\n[ \"$1\" = manager ] && [ \"$2\" = --json ] && [ \"$#\" = 2 ] || exit 3\nprintf '%s' '{\"version\":1,\"shelves\":[],\"items\":[]}'\n").unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        assert_eq!(discover("", [path.clone()]).unwrap(), path);
        run(&path, "manager").await.unwrap();
        assert!(run(&path, "manager; echo injected").await.is_err());
        std::fs::remove_dir_all(directory).unwrap();
    }
}
