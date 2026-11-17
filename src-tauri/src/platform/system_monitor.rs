use crate::system_monitor::sampling::Raw;

pub fn snapshot() -> Result<Raw, String> {
    #[cfg(target_os = "macos")]
    unsafe {
        use std::ffi::{c_char, CStr};
        unsafe extern "C" {
            fn tooki_system_monitor_snapshot() -> *mut c_char;
            fn tooki_system_monitor_free(value: *mut c_char);
        }
        let pointer = tooki_system_monitor_snapshot();
        if pointer.is_null() {
            return Err("Could not read system metrics.".into());
        }
        let result =
            serde_json::from_slice(CStr::from_ptr(pointer).to_bytes()).map_err(|e| e.to_string());
        tooki_system_monitor_free(pointer);
        result
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("System Monitor is currently available on macOS.".into())
    }
}

pub fn open_activity_monitor() -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        let status = std::process::Command::new("/usr/bin/open")
            .args(["-b", "com.apple.ActivityMonitor"])
            .status()
            .map_err(|e| e.to_string())?;
        if status.success() {
            Ok(())
        } else {
            Err("Could not open Activity Monitor.".into())
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("Activity Monitor is only available on macOS.".into())
    }
}
