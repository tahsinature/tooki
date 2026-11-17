use crate::*;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    ffi::{c_char, CStr, CString},
    sync::mpsc::SyncSender,
    time::{Duration, Instant},
};
unsafe extern "C" {
    fn tooki_detective(operation: *const c_char, input: *const c_char) -> *mut c_char;
    fn tooki_detective_free(value: *mut c_char);
}
fn call(operation: &str, input: Value) -> Result<Value, String> {
    let operation = CString::new(operation).map_err(|e| e.to_string())?;
    let input = CString::new(input.to_string()).map_err(|e| e.to_string())?;
    let value = unsafe {
        let ptr = tooki_detective(operation.as_ptr(), input.as_ptr());
        if ptr.is_null() {
            return Err("Native listener returned no response".into());
        }
        let value = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        tooki_detective_free(ptr);
        value
    };
    let value: Value = serde_json::from_str(&value).map_err(|e| e.to_string())?;
    if let Some(error) = value.get("error").and_then(Value::as_str) {
        Err(error.into())
    } else {
        Ok(value)
    }
}
pub fn capabilities() -> Capabilities {
    Capabilities { platform:"macOS".into(),can_observe:true,can_block:true,explanation:"Observes delivery to the app event stream and looks up macOS, Tooki, simple skhd bindings and app menus. Missing delivery suggests interception; it cannot prove which app intercepted it. Accessibility permission is required.".into() }
}
fn key(code: u64) -> Option<String> {
    let name = match code {
        0 => "a",
        1 => "s",
        2 => "d",
        3 => "f",
        4 => "h",
        5 => "g",
        6 => "z",
        7 => "x",
        8 => "c",
        9 => "v",
        11 => "b",
        12 => "q",
        13 => "w",
        14 => "e",
        15 => "r",
        16 => "y",
        17 => "t",
        18 => "1",
        19 => "2",
        20 => "3",
        21 => "4",
        22 => "6",
        23 => "5",
        24 => "=",
        25 => "9",
        26 => "7",
        27 => "-",
        28 => "8",
        29 => "0",
        30 => "]",
        31 => "o",
        32 => "u",
        33 => "[",
        34 => "i",
        35 => "p",
        36 => "enter",
        37 => "l",
        38 => "j",
        39 => "'",
        40 => "k",
        41 => ";",
        42 => "\\",
        43 => ",",
        44 => "/",
        45 => "n",
        46 => "m",
        47 => ".",
        48 => "tab",
        49 => "space",
        50 => "`",
        51 => "backspace",
        53 => "escape",
        122 => "f1",
        120 => "f2",
        99 => "f3",
        118 => "f4",
        96 => "f5",
        97 => "f6",
        98 => "f7",
        100 => "f8",
        101 => "f9",
        109 => "f10",
        103 => "f11",
        111 => "f12",
        105 => "f13",
        107 => "f14",
        113 => "f15",
        106 => "f16",
        64 => "f17",
        79 => "f18",
        80 => "f19",
        90 => "f20",
        115 => "home",
        119 => "end",
        116 => "pageup",
        121 => "pagedown",
        117 => "delete",
        123 => "left",
        124 => "right",
        125 => "down",
        126 => "up",
        _ => return None,
    };
    Some(name.into())
}
struct Pending {
    combo: Combo,
    pid: u64,
    delivered: Option<u64>,
    at: Instant,
}
pub fn run(
    mode: Mode,
    running: &dyn Fn() -> bool,
    report: &mut dyn FnMut(Check),
    ready: SyncSender<Result<(), String>>,
) -> Result<(), String> {
    let start = call("start", json!({"block":mode==Mode::Block})).map(|_| ());
    let _ = ready.send(start.clone());
    start?;
    let result = (|| {
        let mut pending: HashMap<(u64, u64), Pending> = HashMap::new();
        while running() {
            let events = call("poll", json!({}))?;
            for event in events.as_array().into_iter().flatten() {
                let code = event["code"].as_u64().unwrap_or(0);
                let stamp = event["timestamp"].as_u64().unwrap_or(0);
                let id = (code, stamp);
                let pid = event["pid"].as_u64().unwrap_or(0);
                if event["stage"] == 1 {
                    if let Some(press) = pending.get_mut(&id) {
                        press.delivered = Some(pid);
                    }
                } else if let Some(combo) = key(code).and_then(|key| {
                    Combo::new(&key, event["modifiers"].as_u64().unwrap_or(0) as u8)
                }) {
                    pending.entry(id).or_insert(Pending {
                        combo,
                        pid,
                        delivered: None,
                        at: Instant::now(),
                    });
                }
            }
            let finished: Vec<_> = pending
                .iter()
                .filter(|(_, p)| {
                    mode == Mode::Block || p.at.elapsed() >= Duration::from_millis(250)
                })
                .map(|(id, _)| *id)
                .collect();
            for id in finished {
                let p = pending.remove(&id).unwrap();
                let description=call("describe",json!({"pid":p.delivered.unwrap_or(p.pid),"key":p.combo.key,"modifiers":p.combo.modifiers})).unwrap_or(json!({}));
                let app = description["app"].as_str().map(String::from);
                let matches = description["menu"]
                    .as_str()
                    .map(|menu| Assignment {
                        owner: app.clone().unwrap_or_else(|| "App menu".into()),
                        detail: menu.into(),
                    })
                    .into_iter()
                    .collect();
                let (outcome, detail) = if mode == Mode::Block {
                    ("lookup","Tooki blocked this press. Matches describe known assignments, not a tested owner.")
                } else if p.delivered.is_some() {
                    ("delivered","Observed at the app event stream. This does not prove that the app performed an action.")
                } else {
                    ("intercepted","Not observed at the app event stream within 250 ms. A system shortcut or another app may have intercepted it; the owner is unconfirmed.")
                };
                if running() {
                    report(Check {
                        combo: p.combo,
                        outcome: outcome.into(),
                        detail: detail.into(),
                        app,
                        matches,
                    });
                }
            }
        }
        Ok(())
    })();
    let _ = call("stop", json!({}));
    result
}
pub fn system_matches(combo: &Combo) -> Vec<Assignment> {
    let mut found = Vec::new();
    if let Ok(entries) = call("system", json!({})) {
        for entry in entries.as_array().into_iter().flatten() {
            if key(entry["code"].as_u64().unwrap_or(u64::MAX)).as_deref() == Some(&combo.key)
                && entry["modifiers"].as_u64() == Some(combo.modifiers as u64)
            {
                found.push(Assignment {
                    owner: "macOS configuration".into(),
                    detail: entry["name"].as_str().unwrap_or("System shortcut").into(),
                });
            }
        }
    }
    if let Some(home) = std::env::var_os("HOME") {
        for relative in [".config/skhd/skhdrc", ".skhdrc"] {
            let path = std::path::PathBuf::from(&home).join(relative);
            if std::fs::metadata(&path).is_ok_and(|m| m.len() < 1_048_576) {
                if let Ok(text) = std::fs::read_to_string(path) {
                    found.extend(crate::catalog::skhd_matches(&text, combo));
                    break;
                }
            }
        }
    }
    found
}
