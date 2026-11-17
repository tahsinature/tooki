use super::Application;
use std::ffi::{c_char, CStr};
pub fn scan() -> Result<Vec<Application>, String> {
    unsafe extern "C" {
        fn tooki_applications() -> *mut c_char;
        fn tooki_applications_free(value: *mut c_char);
    }
    unsafe {
        let pointer = tooki_applications();
        if pointer.is_null() {
            return Err("Could not read installed applications.".into());
        }
        let result =
            serde_json::from_slice(CStr::from_ptr(pointer).to_bytes()).map_err(|e| e.to_string());
        tooki_applications_free(pointer);
        result
    }
}
pub fn launch(id: &str) -> Result<(), String> {
    let result = std::process::Command::new("/usr/bin/open")
        .args(["-a", id])
        .output()
        .map_err(|e| e.to_string())?;
    if result.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&result.stderr).trim().to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn discovers_system_apps_with_native_icons() {
        let apps = scan().unwrap();
        assert!(!apps.is_empty());
        assert!(apps
            .iter()
            .all(|app| app.id.ends_with(".app") && !app.name.is_empty()));
        assert!(apps
            .iter()
            .any(|app| app.id.starts_with("/System/Applications/")
                && app
                    .icon
                    .as_ref()
                    .is_some_and(|icon| icon.starts_with("data:image/png;base64,"))));
    }
}

pub fn location(id: &str) -> String {
    id.into()
}
pub fn reveal(id: &str) -> Result<(), String> {
    let status = std::process::Command::new("/usr/bin/open")
        .args(["-R", id])
        .status()
        .map_err(|e| e.to_string())?;
    if status.success() {
        Ok(())
    } else {
        Err("Could not reveal application in Finder.".into())
    }
}
pub fn can_uninstall(id: &str) -> bool {
    let Ok(path) = std::fs::canonicalize(id) else {
        return false;
    };
    let home = std::env::var("HOME").unwrap_or_default();
    let allowed = path.starts_with("/Applications")
        || path.starts_with(std::path::Path::new(&home).join("Applications"));
    let own = std::env::current_exe().is_ok_and(|exe| exe.starts_with(&path));
    allowed && !own && path.extension().is_some_and(|ext| ext == "app")
}
pub fn uninstall(id: &str) -> Result<(), String> {
    if !can_uninstall(id) {
        return Err("This application cannot be removed.".into());
    }
    unsafe extern "C" {
        fn tooki_application_trash(path: *const c_char) -> *mut c_char;
        fn tooki_applications_free(value: *mut c_char);
    }
    let path = std::ffi::CString::new(id).map_err(|e| e.to_string())?;
    unsafe {
        let error = tooki_application_trash(path.as_ptr());
        if error.is_null() {
            return Ok(());
        }
        let message = CStr::from_ptr(error).to_string_lossy().into_owned();
        tooki_applications_free(error);
        Err(message)
    }
}

#[cfg(test)]
mod removal_tests {
    use super::*;
    #[test]
    fn system_and_missing_apps_are_not_removable() {
        assert!(!can_uninstall("/System/Applications/Calculator.app"));
        assert!(!can_uninstall("/Applications/tooki-missing-test.app"));
    }
}
