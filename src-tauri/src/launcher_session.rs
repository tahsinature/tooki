use std::time::{Duration, SystemTime};

/// Navigation is kept in memory. Only time spent hidden counts toward expiry.
#[derive(Default)]
pub struct Session {
    visible: bool,
    hidden_at: Option<SystemTime>,
}

impl Session {
    pub fn presented(&mut self) {
        self.visible = true;
        self.hidden_at = None;
    }

    pub fn dismissed(&mut self, now: SystemTime) {
        if self.visible {
            self.visible = false;
            self.hidden_at = Some(now);
        }
    }

    pub fn can_resume(&self, minutes: Option<u32>, now: SystemTime) -> bool {
        if minutes == Some(0) {
            return false;
        }
        if self.visible {
            return true;
        }
        let Some(hidden_at) = self.hidden_at else {
            return false;
        };
        let Some(minutes) = minutes else {
            return true;
        };
        // Wall time includes system sleep. A clock rollback expires the session
        // rather than retaining it for an unexpectedly long time.
        now.duration_since(hidden_at)
            .is_ok_and(|elapsed| elapsed < Duration::from_secs(u64::from(minutes) * 60))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timeout_starts_at_hide_and_expires_at_the_boundary() {
        let now = SystemTime::UNIX_EPOCH + Duration::from_secs(1000);
        let mut session = Session::default();
        assert!(!session.can_resume(Some(5), now));
        session.presented();
        assert!(session.can_resume(Some(5), now + Duration::from_secs(3600)));
        session.dismissed(now);
        assert!(session.can_resume(Some(5), now + Duration::from_secs(299)));
        assert!(!session.can_resume(Some(5), now + Duration::from_secs(300)));
        assert!(!session.can_resume(Some(5), now + Duration::from_secs(86400)));
        assert!(!session.can_resume(Some(5), now - Duration::from_secs(1)));
    }

    #[test]
    fn duplicate_dismissals_do_not_extend_the_timeout_but_reopening_does() {
        let now = SystemTime::UNIX_EPOCH;
        let mut session = Session::default();
        session.presented();
        session.dismissed(now);
        session.dismissed(now + Duration::from_secs(299));
        assert!(!session.can_resume(Some(5), now + Duration::from_secs(300)));
        session.presented();
        session.dismissed(now + Duration::from_secs(300));
        assert!(session.can_resume(Some(5), now + Duration::from_secs(301)));
    }

    #[test]
    fn never_always_custom_and_changed_preferences_are_applied_on_reopen() {
        let now = SystemTime::UNIX_EPOCH;
        let mut session = Session::default();
        assert!(!session.can_resume(None, now));
        session.presented();
        assert!(!session.can_resume(Some(0), now));
        session.dismissed(now);
        let later = now + Duration::from_secs(600);
        assert!(!session.can_resume(Some(5), later));
        assert!(session.can_resume(Some(12), later));
        assert!(session.can_resume(None, later));
        assert!(!session.can_resume(Some(0), later));
    }
}
