use serde::{Deserialize, Serialize};

// Shared modifier bits, independent of any OS key-event representation.
pub const CONTROL: u8 = 1;
pub const ALT: u8 = 2;
pub const SHIFT: u8 = 4;
pub const SUPER: u8 = 8;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct Combo {
    pub key: String,
    pub modifiers: u8,
}
impl Combo {
    pub fn new(key: &str, modifiers: u8) -> Option<Self> {
        let key = normalize_key(key);
        let function = key
            .strip_prefix('f')
            .and_then(|s| s.parse::<u8>().ok())
            .is_some_and(|n| (1..=24).contains(&n));
        if key.is_empty()
            || modifiers > 15
            || (modifiers & (CONTROL | ALT | SUPER) == 0 && !function)
        {
            return None;
        }
        Some(Self { key, modifiers })
    }
    pub fn parse(text: &str) -> Option<Self> {
        let mut parts: Vec<_> = text.split('+').collect();
        let key = parts.pop()?;
        let mut modifiers = 0;
        for part in parts {
            modifiers |= match part.to_lowercase().as_str() {
                "ctrl" | "control" => CONTROL,
                "alt" | "opt" | "option" => ALT,
                "shift" => SHIFT,
                "super" | "win" | "cmd" | "command" | "meta" => SUPER,
                "commandorcontrol" => {
                    if cfg!(target_os = "macos") {
                        SUPER
                    } else {
                        CONTROL
                    }
                }
                "hyper" => 15,
                _ => return None,
            };
        }
        Self::new(key, modifiers)
    }
}
pub fn normalize_key(key: &str) -> String {
    let key = key.to_lowercase();
    let key = key
        .strip_prefix("key")
        .filter(|s| s.len() == 1)
        .or_else(|| key.strip_prefix("digit").filter(|s| s.len() == 1))
        .unwrap_or(&key);
    match key {
        " " => "space",
        "esc" => "escape",
        "return" => "enter",
        "arrowup" => "up",
        "arrowdown" => "down",
        "arrowleft" => "left",
        "arrowright" => "right",
        "comma" => ",",
        "period" => ".",
        "slash" => "/",
        "backslash" => "\\",
        "semicolon" => ";",
        "quote" => "'",
        "bracketleft" => "[",
        "bracketright" => "]",
        "minus" => "-",
        "equal" => "=",
        "backquote" => "`",
        "control" | "shift" | "alt" | "meta" | "super" | "unidentified" | "dead" => "",
        other => other,
    }
    .to_string()
}
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Mode {
    Observe,
    Block,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Assignment {
    pub owner: String,
    pub detail: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Check {
    pub combo: Combo,
    pub outcome: String,
    pub detail: String,
    pub app: Option<String>,
    pub matches: Vec<Assignment>,
}
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Capabilities {
    pub platform: String,
    pub can_observe: bool,
    pub can_block: bool,
    pub explanation: String,
}
#[derive(Clone, Debug)]
pub enum Message {
    Check(Check),
    Stopped(Option<String>),
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_typing_and_modifier_only_events() {
        assert!(Combo::new("a", 0).is_none());
        assert!(Combo::new("A", SHIFT).is_none());
        assert!(Combo::new("Shift", CONTROL).is_none());
        assert!(Combo::new("F5", 0).is_some());
        assert!(Combo::new("a", 32).is_none());
    }
    #[test]
    fn normalizes_recorder_and_native_names() {
        assert_eq!(
            Combo::parse("Super+Shift+KeyA"),
            Combo::new("a", SUPER | SHIFT)
        );
        assert_eq!(Combo::parse("Control+Comma"), Combo::new(",", CONTROL));
        assert_eq!(Combo::parse("cmd+return"), Combo::parse("Super+Enter"));
        assert!(Combo::parse("nonsense+Space").is_none());
    }
}
