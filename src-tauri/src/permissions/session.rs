pub struct Session {
    pub granted: bool,
    pub prompt: bool,
    pub ready: bool,
}
impl Session {
    pub fn new(granted: bool) -> Self {
        Self {
            granted,
            prompt: !granted,
            ready: false,
        }
    }
    pub fn observe(&mut self, granted: bool) -> bool {
        if self.granted == granted {
            return false;
        }
        self.granted = granted;
        self.prompt = !granted;
        true
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn missing_permission_prompts_once_per_launch_and_later_keeps_it_dismissed() {
        let mut session = Session::new(false);
        assert!(session.prompt);
        session.prompt = false;
        assert!(!session.observe(false));
        assert!(!session.prompt);
        assert!(Session::new(false).prompt);
    }
    #[test]
    fn grant_and_revocation_refresh_the_prompt() {
        let mut session = Session::new(false);
        assert!(session.observe(true));
        assert!(!session.prompt);
        assert!(session.observe(false));
        assert!(session.prompt);
        assert!(!Session::new(true).prompt);
    }
}
