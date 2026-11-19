use super::model::{Controller, Mode};
use std::{
    cell::Cell,
    rc::Rc,
    time::{Duration, SystemTime},
};

struct Held(Rc<Cell<usize>>);
impl Drop for Held {
    fn drop(&mut self) {
        self.0.set(self.0.get() + 1);
    }
}

#[test]
fn expiry_replacement_stop_and_shutdown_release_owned_assertions() {
    let releases = Rc::new(Cell::new(0));
    let acquire = |_, _| Ok(Held(releases.clone()));
    let now = SystemTime::UNIX_EPOCH;
    let mut controller = Controller::default();
    assert_eq!(controller.mode, Mode::System);
    controller.start(Some(15), now, acquire).unwrap();
    controller.expire(now + Duration::from_secs(899));
    assert!(controller.session.is_some());
    controller.expire(now + Duration::from_secs(900));
    assert!(controller.session.is_none());
    assert_eq!(releases.get(), 1);
    controller.start(Some(60), now, acquire).unwrap();
    controller.start(None, now, acquire).unwrap();
    assert_eq!(releases.get(), 2);
    controller.expire(now + Duration::from_secs(100000));
    assert!(controller.session.is_some());
    controller.stop();
    controller.stop();
    assert_eq!(releases.get(), 3);
    controller.start(None, now, acquire).unwrap();
    controller.shutdown();
    assert_eq!(releases.get(), 4);
    assert!(controller.start(None, now, acquire).is_err());
    assert!(controller.set_mode(Mode::Display, now, acquire).is_err());
}

#[test]
fn failed_replacements_preserve_the_session_and_mode() {
    let now = SystemTime::UNIX_EPOCH;
    let mut controller = Controller::default();
    controller.start(Some(15), now, |_, _| Ok(())).unwrap();
    let deadline = controller.session.as_ref().unwrap().deadline;
    assert!(controller
        .start(Some(60), now, |_, _| Err("denied".into()))
        .is_err());
    assert!(controller
        .set_mode(Mode::Display, now, |_, _| Err("denied".into()))
        .is_err());
    assert_eq!(controller.mode, Mode::System);
    assert_eq!(controller.session.as_ref().unwrap().deadline, deadline);
    assert_eq!(
        controller.session.as_ref().unwrap().duration_minutes,
        Some(15)
    );
    for minutes in [0, 1, 16, u32::MAX] {
        assert!(controller
            .start(Some(minutes), now, |_, _| panic!(
                "must validate before acquiring"
            ))
            .is_err());
    }
    assert_eq!(controller.session.as_ref().unwrap().deadline, deadline);
}

#[test]
fn mode_changes_keep_the_deadline_and_do_not_restart_expired_sessions() {
    let now = SystemTime::UNIX_EPOCH;
    let mut controller = Controller::default();
    controller.start(Some(15), now, |_, _| Ok(())).unwrap();
    controller
        .set_mode(
            Mode::Display,
            now + Duration::from_secs(100),
            |mode, timeout| {
                assert_eq!(mode, Mode::Display);
                assert_eq!(timeout, Some(Duration::from_secs(800)));
                Ok(())
            },
        )
        .unwrap();
    assert_eq!(
        controller.session.as_ref().unwrap().deadline,
        Some(now + Duration::from_secs(900))
    );
    assert_eq!(
        controller.session.as_ref().unwrap().duration_minutes,
        Some(15)
    );
    controller
        .set_mode(Mode::System, now + Duration::from_secs(900), |_, _| {
            panic!("expired session must not restart")
        })
        .unwrap();
    assert!(controller.session.is_none());
}
