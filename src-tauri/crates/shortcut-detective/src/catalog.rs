use crate::{Assignment, Combo};

pub fn matches(combo: &Combo, launcher: &str) -> Vec<Assignment> {
    let mut result = Vec::new();
    if Combo::parse(launcher).as_ref() == Some(combo) {
        result.push(Assignment {
            owner: "Tooki".into(),
            detail: "Open launcher".into(),
        });
    }
    #[cfg(target_os = "macos")]
    result.extend(crate::platform::system_matches(combo));
    #[cfg(target_os = "linux")]
    result.extend(crate::linux_catalog::matches(combo));
    result
}

/// Deliberately only parses unconditional single-key skhd bindings. Mode selectors,
/// process conditions and .load directives need a real interpreter, so are not guessed.
#[cfg(any(target_os = "macos", test))]
pub fn skhd_matches(text: &str, combo: &Combo) -> Vec<Assignment> {
    text.lines()
        .filter_map(|line| {
            let line = line.trim();
            if line.starts_with('#') || line.starts_with('.') || line.starts_with(':') {
                return None;
            }
            let (keys, command) = line.split_once(':')?;
            if keys.contains(['<', '[', ']', ';']) {
                return None;
            }
            let (modifiers, key) = keys.split_once(" - ")?;
            let shortcut = format!(
                "{}+{}",
                modifiers.split_whitespace().collect::<String>(),
                key.trim()
            );
            (Combo::parse(&shortcut).as_ref() == Some(combo)).then(|| Assignment {
                owner: "skhd configuration".into(),
                detail: command.trim().to_string(),
            })
        })
        .collect()
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn skhd_ignores_conditions_and_matches_modifiers() {
        let text = "# cmd - k : comment\ncmd - k : open -a Terminal\nshift + cmd - k : other\nresize < cmd - k : conditional";
        let found = skhd_matches(text, &Combo::parse("cmd+k").unwrap());
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].detail, "open -a Terminal");
    }
    #[test]
    fn detects_configured_launcher() {
        let found = matches(
            &Combo::parse("Super+Shift+Space").unwrap(),
            "Super+Shift+Space",
        );
        assert!(found.iter().any(|a| a.owner == "Tooki"));
    }
}
