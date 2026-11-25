use serde::{Deserialize, Serialize};
use std::time::{Duration, SystemTime};

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum Mode {
    #[default]
    System,
    Display,
}

pub struct Session<A> {
    pub assertion: A,
    pub deadline: Option<SystemTime>,
    pub duration_minutes: Option<u32>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SavedSession {
    pub deadline: Option<SystemTime>,
    pub duration_minutes: Option<u32>,
}

pub struct Controller<A> {
    pub mode: Mode,
    pub session: Option<Session<A>>,
    pub shutdown: bool,
}

impl<A> Default for Controller<A> {
    fn default() -> Self {
        Self {
            mode: Mode::System,
            session: None,
            shutdown: false,
        }
    }
}

impl<A> Controller<A> {
    pub fn saved_session(&self) -> Option<SavedSession> {
        self.session.as_ref().map(|session| SavedSession {
            deadline: session.deadline,
            duration_minutes: session.duration_minutes,
        })
    }

    pub fn restore(
        &mut self,
        saved: Option<SavedSession>,
        now: SystemTime,
        acquire: impl FnOnce(Mode, Option<Duration>) -> Result<A, String>,
    ) -> Result<(), String> {
        let Some(saved) = saved else {
            self.stop();
            return Ok(());
        };
        let remaining = match (saved.duration_minutes, saved.deadline) {
            (None, None) => None,
            (Some(15 | 60 | 120), Some(deadline)) => {
                let Ok(remaining) = deadline.duration_since(now) else {
                    self.stop();
                    return Ok(());
                };
                if remaining.is_zero() {
                    self.stop();
                    return Ok(());
                }
                Some(remaining)
            }
            _ => return Err("Invalid saved Keep Awake session.".into()),
        };
        let assertion = acquire(self.mode, remaining)?;
        self.session = Some(Session {
            assertion,
            deadline: saved.deadline,
            duration_minutes: saved.duration_minutes,
        });
        Ok(())
    }

    pub fn start(
        &mut self,
        minutes: Option<u32>,
        now: SystemTime,
        acquire: impl FnOnce(Mode, Option<Duration>) -> Result<A, String>,
    ) -> Result<(), String> {
        if self.shutdown {
            return Err("Tooki is shutting down.".into());
        }
        if minutes.is_some_and(|value| !matches!(value, 15 | 60 | 120)) {
            return Err("Choose 15 minutes, 1 hour, 2 hours, or until turned off.".into());
        }
        let duration = minutes.map(|value| Duration::from_secs(u64::from(value) * 60));
        // Acquire first: a failed replacement must leave the existing session intact.
        let assertion = acquire(self.mode, duration)?;
        self.session = Some(Session {
            assertion,
            deadline: duration.map(|value| now + value),
            duration_minutes: minutes,
        });
        Ok(())
    }

    pub fn set_mode(
        &mut self,
        mode: Mode,
        now: SystemTime,
        acquire: impl FnOnce(Mode, Option<Duration>) -> Result<A, String>,
    ) -> Result<(), String> {
        if self.shutdown {
            return Err("Tooki is shutting down.".into());
        }
        self.expire(now);
        if self.mode == mode {
            return Ok(());
        }
        if let Some(session) = &mut self.session {
            let remaining = session
                .deadline
                .map(|deadline| deadline.duration_since(now).unwrap());
            session.assertion = acquire(mode, remaining)?;
        }
        self.mode = mode;
        Ok(())
    }

    pub fn expire(&mut self, now: SystemTime) {
        if self
            .session
            .as_ref()
            .and_then(|session| session.deadline)
            .is_some_and(|deadline| now >= deadline)
        {
            self.session = None;
        }
    }

    pub fn stop(&mut self) {
        self.session = None;
    }

    pub fn shutdown(&mut self) {
        self.shutdown = true;
        self.stop();
    }
}
