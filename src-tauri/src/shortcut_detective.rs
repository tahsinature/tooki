use serde::Serialize;
use shortcut_detective::{Capabilities, Check, Combo, Message, Mode, Session};
use std::{
    sync::Mutex,
    time::{SystemTime, UNIX_EPOCH},
};
use tauri::{AppHandle, Emitter, Manager, WebviewWindow};

#[derive(Clone, Serialize)]
struct RecordedCheck {
    id: u64,
    timestamp: u64,
    #[serde(flatten)]
    check: Check,
}
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot {
    revision: u64,
    replace_checks: bool,
    listening: bool,
    capabilities: Capabilities,
    checks: Vec<RecordedCheck>,
    message: Option<String>,
}
#[derive(Default)]
struct Controller {
    generation: u64,
    revision: u64,
    listening: bool,
    session: Option<Session>,
    next_id: u64,
    checks: Vec<RecordedCheck>,
    message: Option<String>,
}
impl Controller {
    fn snapshot(&self) -> Snapshot {
        Snapshot {
            revision: self.revision,
            replace_checks: true,
            listening: self.listening,
            capabilities: shortcut_detective::capabilities(),
            checks: self.checks.clone(),
            message: self.message.clone(),
        }
    }
    fn publish(&mut self, app: &AppHandle) {
        self.revision += 1;
        let _ = app.emit_to("settings", "detective-changed", self.snapshot());
    }
    fn publish_append(&mut self, app: &AppHandle) {
        self.revision += 1;
        let update = Snapshot {
            revision: self.revision,
            replace_checks: false,
            listening: self.listening,
            capabilities: shortcut_detective::capabilities(),
            checks: self.checks.last().cloned().into_iter().collect(),
            message: self.message.clone(),
        };
        let _ = app.emit_to("settings", "detective-changed", update);
    }
    fn receive(&mut self, generation: u64, message: Message) -> bool {
        if self.generation != generation {
            return false;
        }
        match message {
            Message::Check(check) => self.record(check),
            Message::Stopped(reason) => {
                self.listening = false;
                self.message = reason;
            }
        }
        true
    }
    fn record(&mut self, check: Check) {
        self.next_id += 1;
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;
        self.checks.push(RecordedCheck {
            id: self.next_id,
            timestamp,
            check,
        });
    }
}
#[derive(Default)]
pub struct Detective(Mutex<Controller>);

pub fn stop(app: &AppHandle) {
    let state = app.state::<Detective>();
    if let Ok(mut controller) = state.0.lock() {
        controller.generation += 1;
        controller.listening = false;
        if let Some(session) = &controller.session {
            session.request_stop();
        }
        controller.publish(app);
    };
}
fn launcher(app: &AppHandle) -> String {
    crate::launcher_shortcut::get_launcher_shortcut(app.state()).unwrap_or_default()
}
#[tauri::command]
pub async fn detective_request(
    app: AppHandle,
    window: WebviewWindow,
    operation: String,
    mode: Option<Mode>,
    combo: Option<Combo>,
) -> Result<serde_json::Value, String> {
    if window.label() != "settings" {
        return Err("Shortcut Detective is available in Settings only.".into());
    }
    tauri::async_runtime::spawn_blocking(move || {
        let visible = operation != "start" || window.is_visible().unwrap_or(false);
        let state = app.state::<Detective>();
        let mut controller = state.0.lock().map_err(|e| e.to_string())?;
        match operation.as_str() {
            "status" => {}
            "start" => {
                if !visible {
                    return Err("Open Settings before starting Shortcut Detective.".into());
                }
                controller.generation += 1;
                controller.listening = false;
                controller.session.take(); // joins the previous native listener before replacing it
                controller.message = None;
                let generation = controller.generation;
                match Session::start(mode.unwrap_or(Mode::Observe), launcher(&app)) {
                    Ok((session, receiver)) => {
                        controller.session = Some(session);
                        controller.listening = true;
                        let app = app.clone();
                        std::thread::spawn(move || {
                            for message in receiver {
                                let state = app.state::<Detective>();
                                let Ok(mut controller) = state.0.lock() else {
                                    break;
                                };
                                let append = matches!(message, Message::Check(_));
                                if !controller.receive(generation, message) {
                                    break;
                                }
                                if append {
                                    controller.publish_append(&app);
                                } else {
                                    controller.publish(&app);
                                }
                            }
                        });
                    }
                    Err(error) => {
                        controller.message = Some(error.clone());
                        controller.publish(&app);
                        return Err(error);
                    }
                }
            }
            "stop" => {
                controller.generation += 1;
                controller.listening = false;
                controller.session.take();
            }
            "clear" => {
                controller.checks.clear();
                controller.message = None;
            }
            "lookup" => {
                let combo = combo.ok_or("A shortcut is required")?;
                let combo = Combo::new(&combo.key, combo.modifiers)
                    .ok_or("Use a function key or a key with Control, Alt, Command or Super.")?;
                if combo.key.len() > 32 {
                    return Err("Invalid shortcut".into());
                }
                controller.record(shortcut_detective::lookup(combo, &launcher(&app)));
            }
            _ => return Err("Unknown Detective operation".into()),
        }
        controller.publish(&app);
        serde_json::to_value(controller.snapshot()).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[cfg(test)]
mod tests {
    use super::*;
    fn check(key: &str) -> Message {
        Message::Check(Check {
            combo: Combo::new(key, 8).unwrap(),
            outcome: "observed".into(),
            detail: String::new(),
            app: None,
            matches: vec![],
        })
    }
    #[test]
    fn stopped_session_cannot_overwrite_new_session() {
        let mut controller = Controller {
            generation: 2,
            listening: true,
            ..Default::default()
        };
        assert!(!controller.receive(1, check("a")));
        assert!(!controller.receive(1, Message::Stopped(Some("old error".into()))));
        assert!(controller.listening);
        assert!(controller.message.is_none());
        assert!(controller.checks.is_empty());
        assert!(controller.receive(2, check("b")));
        assert_eq!(controller.checks[0].check.combo.key, "b");
    }
    #[test]
    fn history_retains_every_press_in_order_with_stable_ids() {
        let mut controller = Controller::default();
        for key in ["a", "b", "c", "d", "e", "f", "g"] {
            controller.receive(0, check(key));
        }
        assert_eq!(controller.checks.len(), 7);
        assert_eq!(controller.checks[0].check.combo.key, "a");
        assert_eq!(controller.checks[6].id, 7);
        assert_eq!(controller.checks[6].check.combo.key, "g");
        controller.receive(0, Message::Stopped(Some("permission revoked".into())));
        assert!(!controller.listening);
        assert_eq!(controller.message.as_deref(), Some("permission revoked"));
    }
}
