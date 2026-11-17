use std::path::Path;
#[cfg(target_os = "macos")]
pub fn active() -> bool {
    unsafe extern "C" {
        fn tooki_hyper_active() -> bool;
    }
    unsafe { tooki_hyper_active() }
}
#[cfg(target_os = "windows")]
pub fn active() -> bool {
    SESSION.lock().is_ok_and(|session| session.is_some())
}
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub fn active() -> bool {
    false
}
#[cfg(target_os = "macos")]
pub fn set(enabled: bool, recovery: &Path) -> Result<(), String> {
    use std::ffi::{c_char, CStr, CString};
    unsafe extern "C" {
        fn tooki_hyper_set(enabled: bool, path: *const c_char) -> *mut c_char;
        fn tooki_hyper_free(error: *mut c_char);
    }
    let path = CString::new(recovery.to_string_lossy().as_bytes()).map_err(|e| e.to_string())?;
    unsafe {
        let error = tooki_hyper_set(enabled, path.as_ptr());
        if error.is_null() {
            Ok(())
        } else {
            let message = CStr::from_ptr(error).to_string_lossy().into_owned();
            tooki_hyper_free(error);
            Err(message)
        }
    }
}
#[cfg(target_os = "windows")]
static SESSION: std::sync::Mutex<Option<hyper_key::Session>> = std::sync::Mutex::new(None);
#[cfg(target_os = "windows")]
pub fn set(enabled: bool, _: &Path) -> Result<(), String> {
    let mut session = SESSION.lock().map_err(|e| e.to_string())?;
    if enabled && session.is_none() {
        *session = Some(hyper_key::Session::start()?);
    } else if !enabled {
        *session = None;
    }
    Ok(())
}
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub fn set(enabled: bool, _: &Path) -> Result<(), String> {
    if enabled {
        Err("Use the optional keyd helper setup on Linux. Tooki never installs a system service automatically.".into())
    } else {
        Ok(())
    }
}
