//! Read desktop-owned configuration, never execute commands found in it.
use crate::{Assignment, Combo};
use std::{
    io::Read,
    process::{Command, Stdio},
    sync::Mutex,
    time::{Duration, Instant},
};
type Entries = Vec<(Combo, Assignment)>;
static CACHE: Mutex<Option<(Instant, Entries)>> = Mutex::new(None);
pub fn matches(combo: &Combo) -> Vec<Assignment> {
    let Ok(mut cache) = CACHE.lock() else {
        return vec![];
    };
    if cache
        .as_ref()
        .is_none_or(|(at, _)| at.elapsed() > Duration::from_secs(10))
    {
        *cache = Some((Instant::now(), load()));
    }
    cache
        .as_ref()
        .unwrap()
        .1
        .iter()
        .filter(|(key, _)| key == combo)
        .map(|(_, assignment)| assignment.clone())
        .collect()
}
fn load() -> Entries {
    let mut entries = vec![];
    let desktop = std::env::var("XDG_CURRENT_DESKTOP")
        .unwrap_or_default()
        .to_lowercase();
    if desktop.contains("gnome") || desktop.contains("ubuntu") {
        for schema in [
            "org.gnome.desktop.wm.keybindings",
            "org.gnome.settings-daemon.plugins.media-keys",
            "org.gnome.mutter.keybindings",
        ] {
            if let Some(text) = gsettings(schema) {
                entries.extend(parse_gnome(&text));
            }
        }
    }
    if desktop.contains("kde") {
        let config = std::env::var_os("XDG_CONFIG_HOME")
            .map(std::path::PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME").map(|h| std::path::PathBuf::from(h).join(".config"))
            });
        if let Some(path) = config.map(|p| p.join("kglobalshortcutsrc")) {
            if std::fs::metadata(&path).is_ok_and(|m| m.len() < 1_048_576) {
                if let Ok(text) = std::fs::read_to_string(path) {
                    entries.extend(parse_kde(&text));
                }
            }
        }
    }
    entries
}
fn gsettings(schema: &str) -> Option<String> {
    let mut child = Command::new("gsettings")
        .args(["list-recursively", schema])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    let start = Instant::now();
    let success = loop {
        match child.try_wait() {
            Ok(Some(status)) => break status.success(),
            Ok(None) => {}
            Err(_) => break false,
        }
        if start.elapsed() > Duration::from_millis(400) {
            break false;
        }
        std::thread::sleep(Duration::from_millis(10));
    };
    if !success {
        let _ = child.kill();
        let _ = child.wait();
        return None;
    }
    let mut output = String::new();
    child
        .stdout
        .take()?
        .take(131_072)
        .read_to_string(&mut output)
        .ok()?;
    Some(output)
}
fn parse_gnome(text: &str) -> Entries {
    let mut entries = vec![];
    for line in text.lines() {
        let mut parts = line.splitn(3, ' ');
        let _schema = parts.next();
        let Some(name) = parts.next() else {
            continue;
        };
        let Some(value) = parts.next() else {
            continue;
        };
        if !value.starts_with('[') || value.contains('\\') {
            continue;
        }
        for binding in value.split('\'').skip(1).step_by(2) {
            let mut shortcut = String::new();
            let mut rest = binding;
            while let Some(after) = rest.strip_prefix('<') {
                let Some((modifier, tail)) = after.split_once('>') else {
                    break;
                };
                shortcut.push_str(match modifier.to_lowercase().as_str() {
                    "primary" | "control" => "Control",
                    "super" | "meta" => "Super",
                    "alt" => "Alt",
                    "shift" => "Shift",
                    _ => "unsupported",
                });
                shortcut.push('+');
                rest = tail;
            }
            shortcut.push_str(rest);
            if let Some(combo) = Combo::parse(&shortcut) {
                entries.push((
                    combo,
                    Assignment {
                        owner: "GNOME configuration".into(),
                        detail: name.replace('-', " "),
                    },
                ));
            }
        }
    }
    entries
}
fn parse_kde(text: &str) -> Entries {
    let mut entries = vec![];
    let mut group = "KDE";
    for line in text.lines().map(str::trim) {
        if line.starts_with('[') && line.ends_with(']') {
            group = &line[1..line.len() - 1];
            continue;
        }
        if line.starts_with('#') || line.contains('\\') {
            continue;
        }
        let Some((name, value)) = line.split_once('=') else {
            continue;
        };
        let mut parts = value.splitn(3, ',');
        let Some(active) = parts.next() else {
            continue;
        };
        let _default = parts.next();
        let description = parts.next().unwrap_or(name);
        if let Some(combo) = Combo::parse(active) {
            entries.push((
                combo,
                Assignment {
                    owner: format!("KDE configuration · {group}"),
                    detail: description.into(),
                },
            ));
        }
    }
    entries
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn gnome_parses_enabled_combinations_not_commands() {
        let result=parse_gnome("org.gnome.desktop.wm.keybindings switch-applications ['<Super>Tab', '<Alt>Tab']\norg.gnome.settings-daemon.plugins.media-keys command 'rm -rf /'\norg.gnome.example disabled []");
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].0, Combo::parse("Super+Tab").unwrap());
    }
    #[test]
    fn kde_uses_active_assignment_not_default() {
        let result = parse_kde(
            "[kwin]\nWindow Close=Alt+F4,Meta+Q,Close Window\nDisabled=none,Meta+Z,Disabled action",
        );
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].0, Combo::parse("Alt+F4").unwrap());
    }
}
