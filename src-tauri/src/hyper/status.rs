use serde::Serialize;

#[derive(Default, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    /// Saved intent, independent of whether the native hook could start.
    pub enabled: bool,
    pub active: bool,
    pub available: bool,
    pub helper_required: bool,
    pub permission_required: bool,
    pub error: String,
}

impl Status {
    pub fn apply(
        &mut self,
        apply: impl FnOnce(bool) -> Result<(), String>,
        active: impl FnOnce() -> bool,
    ) {
        self.error = apply(self.enabled).err().unwrap_or_default();
        self.refresh(active());
    }

    pub fn refresh(&mut self, active: bool) {
        self.active = active;
        if self.enabled != active && self.error.is_empty() {
            self.error = if self.enabled {
                "Hyper Key is enabled in your preferences, but remapping is not running. Check permissions and retry."
            } else {
                "Hyper Key is still running. Retry to finish disabling it."
            }.into();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn startup_failure_keeps_enabled_preference_and_retry_clears_error() {
        let mut status = Status {
            enabled: true,
            ..Default::default()
        };
        status.apply(
            |_| Err("Accessibility permission required".into()),
            || false,
        );
        assert!(status.enabled);
        assert!(!status.active);
        assert_eq!(status.error, "Accessibility permission required");
        status.apply(
            |enabled| {
                assert!(enabled);
                Ok(())
            },
            || true,
        );
        assert!(status.enabled && status.active);
        assert!(status.error.is_empty());
    }

    #[test]
    fn failed_stop_does_not_claim_remapping_is_off() {
        let mut status = Status::default();
        status.apply(
            |enabled| {
                assert!(!enabled);
                Err("Could not restore mapping".into())
            },
            || true,
        );
        assert!(!status.enabled);
        assert!(status.active);
        assert!(!status.error.is_empty());
    }

    #[test]
    fn lost_hook_does_not_change_preference() {
        let mut status = Status {
            enabled: true,
            active: true,
            ..Default::default()
        };
        status.refresh(false);
        assert!(status.enabled);
        assert!(!status.active);
        assert!(!status.error.is_empty());
    }
}
