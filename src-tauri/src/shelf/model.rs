use serde::{Deserialize, Serialize};
#[derive(Clone, Serialize, Deserialize, Default)]
pub struct Library {
    pub shelves: Vec<Shelf>,
    #[serde(default)]
    pub last_file_transaction: Option<String>,
    #[serde(default)]
    pub settings: Settings,
    #[serde(default)]
    pub retired: Vec<RetiredItem>,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct Shelf {
    pub id: String,
    pub name: String,
    pub items: Vec<Item>,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Item {
    pub id: String,
    pub name: String,
    pub path: String,
    pub owned: bool,
    pub original_path: Option<String>,
    #[serde(default)]
    pub text: Option<String>,
    #[serde(default)]
    pub is_link: bool,
}
pub fn identifier() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT: AtomicU64 = AtomicU64::new(0);
    format!(
        "{:x}-{:x}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    )
}
pub fn name(value: &str) -> Result<String, String> {
    let value = value.trim();
    if value.is_empty() || value.chars().count() > 100 || value.chars().any(char::is_control) {
        return Err("Use a name between 1 and 100 characters.".into());
    }
    Ok(value.into())
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Settings {
    pub enabled: bool,
    #[serde(default)]
    pub show_on_shift_drag: bool,
    #[serde(default)]
    pub remove_after_drag_out: bool,
}
impl Default for Settings {
    fn default() -> Self {
        Self {
            enabled: true,
            show_on_shift_drag: false,
            remove_after_drag_out: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn existing_libraries_enable_shelf_by_default() {
        let library: Library = serde_json::from_str(r#"{"shelves":[]}"#).unwrap();
        assert!(library.settings.enabled);
    }
    #[test]
    fn disabled_setting_round_trips() {
        let library = Library {
            shelves: vec![],
            settings: Settings {
                enabled: false,
                ..Settings::default()
            },
            retired: vec![],
            last_file_transaction: None,
        };
        let saved = serde_json::to_string(&library).unwrap();
        assert!(
            !serde_json::from_str::<Library>(&saved)
                .unwrap()
                .settings
                .enabled
        );
    }
}

/// Dropped copies remain readable while the receiving app finishes its transfer.
#[derive(Clone, Serialize, Deserialize)]
pub struct RetiredItem {
    pub item: Item,
    pub delete_after: u64,
}
pub fn now_seconds() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
impl Library {
    pub fn finish_drag(&mut self, shelf_id: &str, ids: &[String], dropped: bool, now: u64) -> bool {
        if !dropped || !self.settings.remove_after_drag_out {
            return false;
        }
        let Some(shelf) = self.shelves.iter_mut().find(|s| s.id == shelf_id) else {
            return false;
        };
        let mut removed = vec![];
        shelf.items.retain(|item| {
            if ids.contains(&item.id) {
                removed.push(item.clone());
                false
            } else {
                true
            }
        });
        let changed = !removed.is_empty();
        self.retired.extend(
            removed
                .into_iter()
                .filter(|i| i.owned)
                .map(|item| RetiredItem {
                    item,
                    delete_after: now + 60,
                }),
        );
        changed
    }
}

#[cfg(test)]
mod drag_tests {
    use super::*;
    fn library() -> Library {
        Library {
            settings: Settings {
                remove_after_drag_out: true,
                ..Settings::default()
            },
            shelves: vec![Shelf {
                id: "shelf".into(),
                name: "Shelf".into(),
                items: vec![
                    Item {
                        id: "copy".into(),
                        name: "Copy".into(),
                        path: "/copy".into(),
                        owned: true,
                        original_path: None,
                        text: None,
                        is_link: false,
                    },
                    Item {
                        id: "reference".into(),
                        name: "Original".into(),
                        path: "/original".into(),
                        owned: false,
                        original_path: None,
                        text: None,
                        is_link: false,
                    },
                    Item {
                        id: "new".into(),
                        name: "Added during drag".into(),
                        path: "/new".into(),
                        owned: false,
                        original_path: None,
                        text: None,
                        is_link: false,
                    },
                ],
            }],
            retired: vec![],
            last_file_transaction: None,
        }
    }
    #[test]
    fn cancelled_or_disabled_drag_keeps_every_item() {
        let mut lib = library();
        assert!(!lib.finish_drag("shelf", &["copy".into()], false, 100));
        lib.settings.remove_after_drag_out = false;
        assert!(!lib.finish_drag("shelf", &["copy".into()], true, 100));
        assert_eq!(lib.shelves[0].items.len(), 3);
        assert!(lib.retired.is_empty());
    }
    #[test]
    fn successful_drag_only_removes_snapshot_and_retires_owned_files() {
        let mut lib = library();
        let ids = vec!["copy".into(), "reference".into()];
        assert!(lib.finish_drag("shelf", &ids, true, 100));
        assert_eq!(lib.shelves[0].items[0].id, "new");
        assert_eq!(lib.retired.len(), 1);
        assert_eq!(lib.retired[0].delete_after, 160);
        assert!(!lib.finish_drag("shelf", &ids, true, 101));
        assert_eq!(lib.retired.len(), 1);
    }
}
