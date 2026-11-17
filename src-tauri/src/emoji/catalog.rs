use serde::Serialize;
use std::sync::OnceLock;

pub const GROUPS: [&str; 9] = [
    "Smileys & Emotion",
    "People & Body",
    "Animals & Nature",
    "Food & Drink",
    "Travel & Places",
    "Activities",
    "Objects",
    "Symbols",
    "Flags",
];

#[derive(Clone, Serialize)]
pub struct Emoji {
    pub character: String,
    pub name: String,
    pub group: String,
    pub keywords: Vec<String>,
    pub shortcodes: Vec<String>,
    pub shortcode: String,
}

fn parse() -> Vec<Emoji> {
    include_str!("../../emoji/catalog.tsv")
        .lines()
        .filter_map(|line| {
            let fields: Vec<_> = line.split('\t').collect();
            if fields.len() != 5 {
                return None;
            }
            let group = GROUPS.get(fields[2].parse::<usize>().ok()?)?;
            let shortcodes = words(fields[4]);
            Some(Emoji {
                character: fields[0].into(),
                name: fields[1].into(),
                group: (*group).into(),
                keywords: words(fields[3]),
                shortcode: shortcodes
                    .first()
                    .cloned()
                    .unwrap_or_else(|| fields[1].replace(' ', "_")),
                shortcodes,
            })
        })
        .collect()
}
fn words(value: &str) -> Vec<String> {
    value
        .split(',')
        .filter(|word| !word.is_empty())
        .map(str::to_owned)
        .collect()
}

pub fn all() -> &'static [Emoji] {
    static CATALOG: OnceLock<Vec<Emoji>> = OnceLock::new();
    CATALOG.get_or_init(|| {
        parse()
            .into_iter()
            .filter(|emoji| supported(&emoji.character))
            .collect()
    })
}

#[cfg(target_os = "macos")]
fn supported(character: &str) -> bool {
    unsafe extern "C" {
        fn tooki_emoji_supported(character: *const std::ffi::c_char) -> bool;
    }
    let Ok(character) = std::ffi::CString::new(character) else {
        return false;
    };
    unsafe { tooki_emoji_supported(character.as_ptr()) }
}
#[cfg(not(target_os = "macos"))]
fn supported(_: &str) -> bool {
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bundled_catalog_has_unique_characters_and_expected_metadata() {
        let catalog = parse();
        assert!(catalog.len() > 1500);
        let mut seen = std::collections::HashSet::new();
        for item in &catalog {
            assert!(seen.insert(&item.character));
        }
        let rocket = catalog.iter().find(|item| item.character == "🚀").unwrap();
        assert_eq!(rocket.shortcode, "rocket");
        assert!(catalog.iter().any(|item| item.character == "🇨🇦"));
        assert!(catalog.iter().any(|item| item.character == "👨‍👩‍👧"));
        assert!(!catalog.iter().any(|item| item.character == "🏻"));
    }
}
