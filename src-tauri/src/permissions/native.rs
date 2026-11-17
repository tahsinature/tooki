pub fn required() -> bool {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_permissions_accessibility() -> bool;
        }
        unsafe { !tooki_permissions_accessibility() }
    }
    #[cfg(not(target_os = "macos"))]
    {
        false
    }
}
pub fn open_settings() -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_permissions_open_accessibility() -> bool;
        }
        if unsafe { tooki_permissions_open_accessibility() } {
            return Ok(());
        }
        Err("Could not open Accessibility Settings.".into())
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("Accessibility Settings is only available on macOS.".into())
    }
}
