use std::time::{Duration, Instant};

#[derive(Default)]
pub struct Confirmation {
    next_id: u64,
    pending: Option<(u64, Instant)>,
}

impl Confirmation {
    pub fn begin(&mut self, now: Instant) -> u64 {
        self.next_id += 1;
        self.pending = Some((self.next_id, now + Duration::from_secs(300)));
        self.next_id
    }

    pub fn current(&self, now: Instant) -> Option<u64> {
        self.pending
            .filter(|(_, expiry)| now < *expiry)
            .map(|(id, _)| id)
    }

    pub fn consume(&mut self, id: u64, now: Instant) -> bool {
        if self.current(now) != Some(id) {
            return false;
        }
        self.pending = None;
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn confirmation_is_required_single_use_and_expires() {
        let now = Instant::now();
        let mut confirmation = Confirmation::default();
        assert!(!confirmation.consume(0, now));
        let first = confirmation.begin(now);
        let second = confirmation.begin(now);
        assert!(!confirmation.consume(first, now));
        assert!(confirmation.consume(second, now));
        assert!(!confirmation.consume(second, now));
        let third = confirmation.begin(now);
        assert!(!confirmation.consume(third, now + Duration::from_secs(300)));
    }

    #[test]
    fn retry_requires_a_fresh_request_and_survives_old_dialog_cleanup() {
        let now = Instant::now();
        let mut confirmation = Confirmation::default();
        let attempt = confirmation.begin(now);
        assert!(confirmation.consume(attempt, now));
        // Finder fails after authorization was consumed. Reopening the
        // confirmation creates a new token before the old dialog unmounts.
        let retry = confirmation.begin(now);
        assert!(!confirmation.consume(attempt, now));
        assert_eq!(confirmation.current(now), Some(retry));
        assert!(confirmation.consume(retry, now));
        assert!(!confirmation.consume(retry, now));
    }
}
