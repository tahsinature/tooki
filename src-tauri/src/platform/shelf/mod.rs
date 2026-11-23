//! Only adapters that can distinguish content drags from text selection advertise support.
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
pub use macos::{configure, stop};
pub fn available() -> bool {
    cfg!(target_os = "macos")
}
#[cfg(not(target_os = "macos"))]
pub fn configure(_: &tauri::AppHandle, enabled: bool, _: extern "C" fn(u8)) -> Result<(), String> {
    if enabled {
        Err("Global content-drag observation is not available on this desktop. Open a shelf manually to drop files.".into())
    } else {
        Ok(())
    }
}
#[cfg(not(target_os = "macos"))]
pub fn stop() {}

pub mod content;

// Retained only for the archived, inactive shelf implementation.
#[allow(dead_code)]
pub mod drag;
