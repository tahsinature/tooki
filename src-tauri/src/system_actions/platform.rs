use super::Volume;

pub fn supports(capability: &str, platform: &str) -> bool {
    platform == "macos"
        && matches!(
            capability,
            "system.monitor" | "system.actions" | "power.sleep" | "power.keepAwake" | "trash.empty" | "storage.eject"
        )
}

#[cfg(target_os = "macos")]
fn run(program: &str, args: &[&str]) -> Result<(), String> {
    let output = std::process::Command::new(program)
        .args(args)
        .output()
        .map_err(|e| e.to_string())?;
    if output.status.success() {
        return Ok(());
    }
    let error = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if let Some(message) = finder_error_message(&error) {
        return Err(message.into());
    }
    Err(if error.is_empty() {
        format!("System action failed ({})", output.status)
    } else {
        error
    })
}

#[cfg(any(target_os = "macos", test))]
fn finder_error_message(error: &str) -> Option<&'static str> {
    // Apple event error codes are stable across localized Finder messages.
    if error.trim_end().ends_with("(-128)") {
        return Some("Empty Trash was canceled in Finder. Try again, or empty Trash directly in Finder.");
    }
    if error.trim_end().ends_with("(-1743)") {
        return Some("Finder access was denied. Enable Tooki in System Settings → Privacy & Security → Automation, then try again.");
    }
    None
}

pub fn sleep() -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        run("/usr/bin/pmset", &["sleepnow"])
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("Sleep is not supported on this platform yet.".into())
    }
}

pub fn empty_trash() -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        run(
            "/usr/bin/osascript",
            &["-e", "tell application \"Finder\" to empty trash"],
        )
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("Empty Trash is not supported on this platform yet.".into())
    }
}

pub fn volumes() -> Result<Vec<Volume>, String> {
    #[cfg(target_os = "macos")]
    {
        use std::ffi::{c_char, CStr};
        unsafe extern "C" {
            fn tooki_ejectable_volumes() -> *mut c_char;
            fn tooki_volumes_free(value: *mut c_char);
        }
        unsafe {
            let pointer = tooki_ejectable_volumes();
            if pointer.is_null() {
                return Err("Could not read mounted disks.".into());
            }
            let result = serde_json::from_slice(CStr::from_ptr(pointer).to_bytes())
                .map_err(|e| e.to_string());
            tooki_volumes_free(pointer);
            result
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("Disk ejection is not supported on this platform yet.".into())
    }
}

pub fn eject(id: &str) -> Result<(), String> {
    // Never accept a caller-supplied path, or force-eject a busy volume.
    let volume = select_volume(volumes()?, id)?;
    #[cfg(target_os = "macos")]
    {
        run("/usr/sbin/diskutil", &["eject", &volume.path])
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = volume;
        Err("Disk ejection is not supported on this platform yet.".into())
    }
}

fn select_volume(volumes: Vec<Volume>, id: &str) -> Result<Volume, String> {
    volumes
        .into_iter()
        .find(|volume| volume.id == id)
        .ok_or_else(|| "This disk is no longer available. Refresh the list and try again.".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn finder_errors_distinguish_cancellation_from_denied_access() {
        assert!(finder_error_message("29:40: execution error: Finder got an error: The operation can’t be completed. (-128)\n")
            .unwrap().contains("canceled in Finder"));
        assert!(finder_error_message("Not authorized to send Apple events to Finder. (-1743)")
            .unwrap().contains("Automation"));
        assert_eq!(finder_error_message("File -128 could not be removed. (-43)"), None);
        assert_eq!(finder_error_message("Other error"), None);
    }
    #[test]
    fn capabilities_fail_closed_for_unknown_platforms_and_actions() {
        for capability in [
            "system.actions",
            "system.monitor",
            "power.sleep",
            "power.keepAwake",
            "trash.empty",
            "storage.eject",
        ] {
            assert!(supports(capability, "macos"));
            for platform in ["windows", "linux", "unknown"] {
                assert!(!supports(capability, platform));
            }
        }
        assert!(!supports("storage.erase", "macos"));
    }
    #[test]
    fn stale_or_arbitrary_volume_ids_are_rejected() {
        let volumes = || {
            vec![Volume {
                id: "uuid".into(),
                name: "Test disk".into(),
                path: "/Volumes/Test disk".into(),
            }]
        };
        assert!(select_volume(volumes(), "/").is_err());
        assert!(select_volume(volumes(), "removed").is_err());
        assert!(select_volume(vec![], "uuid").is_err());
        assert_eq!(
            select_volume(volumes(), "uuid").unwrap().path,
            "/Volumes/Test disk"
        );
    }
    #[cfg(target_os = "macos")]
    #[test]
    fn native_enumeration_is_readable_without_ejecting() {
        for volume in volumes().unwrap() {
            assert!(!volume.id.is_empty());
            assert_ne!(volume.path, "/");
        }
    }
}
