pub struct Guard(#[cfg(target_os = "macos")] i32);
#[cfg(target_os = "macos")]
impl Drop for Guard {
    fn drop(&mut self) {
        unsafe extern "C" {
            fn tooki_instance_guard_release(descriptor: i32);
        }
        unsafe {
            tooki_instance_guard_release(self.0);
        }
    }
}

pub fn acquire(identifier: &str) -> Result<Guard, String> {
    // Avoid silently running an incorrectly configured debug executable with the
    // production identity (for example, a direct cargo run without the overlay).
    if cfg!(debug_assertions) && identifier != "us.tahsin.tooki.dev" {
        return Err("Development builds require the dev identity. Use make dev or make app CONFIGURATION=debug.".into());
    }
    #[cfg(target_os = "macos")]
    {
        use std::ffi::{c_char, CStr};
        unsafe extern "C" {
            fn tooki_instance_guard(development: bool, error: *mut *mut c_char) -> i32;
            fn tooki_instance_guard_free(error: *mut c_char);
        }
        let mut error = std::ptr::null_mut();
        let descriptor = unsafe { tooki_instance_guard(cfg!(debug_assertions), &mut error) };
        if descriptor < 0 {
            let message = if error.is_null() {
                "Could not acquire Tooki’s session lock.".into()
            } else {
                let message = unsafe { CStr::from_ptr(error) }
                    .to_string_lossy()
                    .into_owned();
                unsafe {
                    tooki_instance_guard_free(error);
                }
                message
            };
            return Err(message);
        }
        Ok(Guard(descriptor))
    }
    #[cfg(not(target_os = "macos"))]
    Ok(Guard())
}
