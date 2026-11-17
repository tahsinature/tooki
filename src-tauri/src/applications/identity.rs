use super::Application;
use tauri::Manager;
pub fn storage_key(app: &tauri::AppHandle, id: &str) -> String {
    if id.starts_with("command:") || id.starts_with("bundle:") {
        return id.into();
    }
    #[cfg(target_os = "macos")]
    {
        if let Some(bundle) = bundle_id(id) {
            return format!("bundle:{bundle}");
        }
    }
    let _ = app;
    id.into()
}
#[cfg(target_os = "macos")]
fn bundle_id(path: &str) -> Option<String> {
    use std::ffi::{c_char, CStr, CString};
    unsafe extern "C" {
        fn tooki_application_bundle_id(path: *const c_char) -> *mut c_char;
        fn tooki_applications_free(value: *mut c_char);
    }
    let path = CString::new(path).ok()?;
    unsafe {
        let result = tooki_application_bundle_id(path.as_ptr());
        if result.is_null() {
            return None;
        }
        let id = CStr::from_ptr(result).to_string_lossy().into_owned();
        tooki_applications_free(result);
        Some(id)
    }
}
pub fn runtime_id(app: &tauri::AppHandle, key: &str) -> String {
    let Some(bundle) = key.strip_prefix("bundle:") else {
        return key.into();
    };
    app.state::<super::Catalog>()
        .apps
        .lock()
        .unwrap()
        .iter()
        .find(|entry: &&Application| entry.bundle_id.as_deref() == Some(bundle))
        .map(|entry| entry.id.clone())
        .unwrap_or_else(|| key.into())
}
