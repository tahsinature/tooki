use super::model::Mode;
use std::time::Duration;

pub struct Assertion {
    #[cfg(target_os = "macos")]
    id: u32,
}

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn tooki_keep_awake_create(display: bool, seconds: f64, identifier: *mut u32) -> i32;
    fn tooki_keep_awake_active(identifier: u32) -> bool;
    fn tooki_keep_awake_release(identifier: u32) -> i32;
}

impl Assertion {
    pub fn acquire(mode: Mode, timeout: Option<Duration>) -> Result<Self, String> {
        #[cfg(target_os = "macos")]
        {
            let mut id = 0;
            let result = unsafe {
                tooki_keep_awake_create(
                    mode == Mode::Display,
                    timeout.map_or(0.0, |value| value.as_secs_f64()),
                    &mut id,
                )
            };
            if result != 0 {
                return Err(format!("macOS could not start Keep Awake ({result:#x})."));
            }
            Ok(Self { id })
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = (mode, timeout);
            Err("Keep Awake is not supported on this platform yet.".into())
        }
    }

    pub fn active(&self) -> bool {
        #[cfg(target_os = "macos")]
        unsafe {
            tooki_keep_awake_active(self.id)
        }
        #[cfg(not(target_os = "macos"))]
        {
            false
        }
    }
}

impl Drop for Assertion {
    fn drop(&mut self) {
        #[cfg(target_os = "macos")]
        {
            // A timed assertion may already have been released by macOS.
            // Releasing that expired ID is harmless; no resource remains to own.
            unsafe { tooki_keep_awake_release(self.id) };
        }
    }
}

#[cfg(all(test, target_os = "macos"))]
mod tests {
    use super::*;

    #[test]
    fn native_assertions_release_on_drop_and_expire_without_a_frontend() {
        let assertion = Assertion::acquire(Mode::System, None).unwrap();
        assert!(assertion.active());
        let id = assertion.id;
        drop(assertion);
        assert!(!unsafe { tooki_keep_awake_active(id) });

        let assertion = Assertion::acquire(Mode::System, Some(Duration::from_secs(1))).unwrap();
        assert!(assertion.active());
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        while assertion.active() && std::time::Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(50));
        }
        assert!(!assertion.active());
    }
}
