use super::model::{Controller, Mode};
use std::{
    cell::Cell,
    rc::Rc,
    time::{Duration, SystemTime},
};

struct Held(Rc<Cell<usize>>);

#[test]
fn restart_restores_mode_and_only_remaining_time() {
    let now = SystemTime::UNIX_EPOCH + Duration::from_secs(10000);
    let mut original = Controller::default();
    original.mode = Mode::Display;
    original.start(Some(15), now, |_, _| Ok(())).unwrap();
    let saved = original.saved_session();
    original.shutdown();
    let mut restored = Controller::default();
    restored.mode = Mode::Display;
    restored
        .restore(
            saved.clone(),
            now + Duration::from_secs(300),
            |mode, timeout| {
                assert_eq!(mode, Mode::Display);
                assert_eq!(timeout, Some(Duration::from_secs(600)));
                Ok(())
            },
        )
        .unwrap();
    assert_eq!(restored.saved_session(), saved);
    for seconds in [900, 901] {
        restored
            .restore(saved.clone(), now + Duration::from_secs(seconds), |_, _| {
                panic!("expired session restarted")
            })
            .unwrap();
        assert!(restored.session.is_none());
    }
}

#[test]
fn indefinite_session_and_explicit_off_survive_disk_roundtrip() {
    let directory =
        std::env::temp_dir().join(format!("tooki-awake-session-{}", std::process::id()));
    let path = directory.join("session.json");
    let mut original = Controller::default();
    original
        .start(None, SystemTime::now(), |_, _| Ok(()))
        .unwrap();
    super::persistence::write(&path, &original.saved_session()).unwrap();
    original.shutdown();
    let mut restored = Controller::default();
    restored
        .restore(
            super::persistence::read(&path).unwrap(),
            SystemTime::now(),
            |_, timeout| {
                assert_eq!(timeout, None);
                Ok(())
            },
        )
        .unwrap();
    assert!(restored.session.is_some());
    super::persistence::write(&path, &None).unwrap();
    restored
        .restore(
            super::persistence::read(&path).unwrap(),
            SystemTime::now(),
            |_, _| panic!("off session restarted"),
        )
        .unwrap();
    assert!(restored.session.is_none());
    std::fs::remove_dir_all(directory).unwrap();
}

#[test]
fn old_preferences_default_to_system_and_new_mode_roundtrips() {
    let mut preferences: super::preferences::Preferences =
        serde_json::from_str(r#"{"showMenuBarIcon":false}"#).unwrap();
    assert_eq!(preferences.mode, Mode::System);
    assert!(!preferences.show_menu_bar_icon);
    preferences.mode = Mode::Display;
    let restored: super::preferences::Preferences =
        serde_json::from_slice(&serde_json::to_vec(&preferences).unwrap()).unwrap();
    assert_eq!(restored.mode, Mode::Display);
    assert!(!restored.show_menu_bar_icon);
}

#[test]
fn failed_restore_does_not_replace_existing_session() {
    let mut controller = Controller::default();
    controller
        .start(None, SystemTime::now(), |_, _| Ok(()))
        .unwrap();
    let saved = controller.saved_session();
    assert!(controller
        .restore(
            saved.clone(),
            SystemTime::now(),
            |_, _| Err("denied".into())
        )
        .is_err());
    assert_eq!(controller.saved_session(), saved);
    assert!(controller
        .restore(
            Some(super::model::SavedSession {
                deadline: None,
                duration_minutes: Some(15)
            }),
            SystemTime::now(),
            |_, _| panic!("invalid session acquired")
        )
        .is_err());
    assert_eq!(controller.saved_session(), saved);
}
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
