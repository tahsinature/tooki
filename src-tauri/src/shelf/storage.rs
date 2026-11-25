use crate::file_copy::copy_tree;
use super::model::*;
use std::{
    fs,
    path::{Path, PathBuf},
};
pub struct Storage {
    pub root: PathBuf,
    pub library: Library,
}
impl Storage {
    pub fn open(root: PathBuf) -> Result<Self, String> {
        fs::create_dir_all(root.join("items")).map_err(|e| e.to_string())?;
        let root = root.canonicalize().map_err(|e| e.to_string())?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&root, fs::Permissions::from_mode(0o700))
                .map_err(|e| e.to_string())?;
        }
        let mut path = root.join("library.json");
        if !path.exists() && root.join("library.backup.json").exists() {
            path = root.join("library.backup.json");
        }
        let library = if path.exists() {
            serde_json::from_slice(&fs::read(path).map_err(|e| e.to_string())?)
                .map_err(|e| format!("Could not read Shelf library: {e}"))?
        } else {
            Library::default()
        };
        super::file_transaction::recover(&root, &library)?;
        let mut store = Self { root, library };
        store.prune_missing()?;
        Ok(store)
    }
    /// Swift discards stale references when restoring a shelf. Permission errors are not missing files.
    fn prune_missing(&mut self) -> Result<(), String> {
        let mut next = self.library.clone();
        let mut changed = false;
        for shelf in &mut next.shelves {
            shelf.items.retain(|item| {
                let missing = fs::symlink_metadata(&item.path)
                    .is_err_and(|e| e.kind() == std::io::ErrorKind::NotFound);
                changed |= missing;
                !missing
            });
        }
        if changed {
            self.save(next)?;
        }
        Ok(())
    }
    pub fn save(&mut self, mut next: Library) -> Result<(), String> {
        // A removed owned folder may still contain another shelf's reference. Retire it
        // until that reference is removed, so preserving it now does not leak it forever.
        for item in self
            .library
            .shelves
            .iter()
            .flat_map(|s| &s.items)
            .filter(|i| i.owned)
        {
            let still_present = next
                .shelves
                .iter()
                .flat_map(|s| &s.items)
                .any(|i| i.id == item.id);
            let referenced = next
                .shelves
                .iter()
                .flat_map(|s| &s.items)
                .any(|i| Path::new(&i.path).starts_with(&item.path));
            if !still_present && referenced && !next.retired.iter().any(|r| r.item.id == item.id) {
                next.retired.push(RetiredItem {
                    item: item.clone(),
                    delete_after: now_seconds(),
                });
            }
        }
        let temp = self.root.join("library.tmp");
        let bytes = serde_json::to_vec_pretty(&next).map_err(|e| e.to_string())?;
        fs::write(&temp, bytes).map_err(|e| e.to_string())?;
        // Preserve the last valid library before replacing it, including on Windows.
        let path = self.root.join("library.json");
        if path.exists() {
            fs::copy(&path, self.root.join("library.backup.json")).map_err(|e| e.to_string())?;
        }
        #[cfg(target_os = "windows")]
        if path.exists() {
            fs::remove_file(&path).map_err(|e| e.to_string())?;
        }
        fs::rename(temp, path).map_err(|e| e.to_string())?;
        self.library = next;
        Ok(())
    }
    pub fn file(&self, path: &Path, copy: bool) -> Result<Item, String> {
        let original = path.canonicalize().map_err(|e| e.to_string())?;
        let id = identifier();
        let name = original
            .file_name()
            .ok_or("Choose a file or folder, not a filesystem root.")?
            .to_string_lossy()
            .into_owned();
        let destination = if copy {
            let dir = self.root.join("items").join(&id);
            fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
            let destination = dir.join(&name);
            if destination.starts_with(&original) {
                let _ = fs::remove_dir(&dir);
                return Err(
                    "Cannot copy a folder into itself. Add it as a reference instead.".into(),
                );
            }
            if let Err(error) = copy_tree(&original, &destination) {
                let _ = fs::remove_dir_all(dir);
                return Err(error);
            }
            destination
        } else {
            original.clone()
        };
        Ok(Item {
            id,
            name,
            path: destination.to_string_lossy().into(),
            owned: copy,
            original_path: copy.then(|| original.to_string_lossy().into()),
            text: None,
            is_link: false,
        })
    }
    pub fn text(&self, text: &str) -> Result<Item, String> {
        if text.trim().is_empty() {
            return Err("There is no text to add.".into());
        }
        let title = text
            .split(|c: char| !c.is_alphanumeric())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join(" ")
            .chars()
            .take(30)
            .collect::<String>();
        let mut item = self.bytes(
            &format!("{}.txt", if title.is_empty() { "Text" } else { &title }),
            text.as_bytes(),
        )?;
        item.text = Some(text.into());
        Ok(item)
    }
    pub fn cleanup_retired(&mut self, now: u64) -> Result<(), String> {
        let mut next = self.library.clone();
        let mut removed = vec![];
        next.retired.retain(|entry| {
            let in_use = next.shelves.iter().flat_map(|s| &s.items).any(|i| {
                Path::new(&entry.item.path)
                    .parent()
                    .is_some_and(|directory| Path::new(&i.path).starts_with(directory))
            });
            if entry.delete_after <= now && !in_use {
                removed.push(entry.item.clone());
                false
            } else {
                true
            }
        });
        if removed.is_empty() {
            return Ok(());
        }
        self.save(next)?;
        for item in removed {
            self.remove_owned(&item);
        }
        Ok(())
    }
    pub fn remove_owned(&self, item: &Item) {
        if self
            .library
            .shelves
            .iter()
            .flat_map(|s| &s.items)
            .any(|other| Path::new(&other.path).starts_with(&item.path))
        {
            return;
        }
        // Never use an arbitrary stored path as a deletion target.
        if item.owned
            && !item.id.is_empty()
            && item.id.chars().all(|c| c.is_ascii_hexdigit() || c == '-')
        {
            let dir = self.root.join("items").join(&item.id);
            if Path::new(&item.path).parent() == Some(dir.as_path()) {
                let _ = fs::remove_dir_all(dir);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("tooki-shelf-test-{}", identifier()));
            fs::create_dir_all(&path).unwrap();
            Self(path)
        }
        fn store(&self) -> Storage {
            Storage::open(self.0.join("library")).unwrap()
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }
    #[test]
    fn removing_references_and_copies_preserves_originals() {
        let f = Fixture::new();
        let source = f.0.join("original.txt");
        fs::write(&source, "original").unwrap();
        let store = f.store();
        let reference = store.file(&source, false).unwrap();
        let copy = store.file(&source, true).unwrap();
        assert_ne!(reference.path, copy.path);
        assert_eq!(fs::read_to_string(&copy.path).unwrap(), "original");
        store.remove_owned(&reference);
        store.remove_owned(&copy);
        assert!(source.exists());
        assert!(!Path::new(&copy.path).exists());
    }
    #[test]
    fn library_and_materialized_text_survive_reopen() {
        let f = Fixture::new();
        let mut store = f.store();
        let item = store.text("hello\nworld").unwrap();
        store
            .save(Library {
                settings: Settings::default(),
                retired: vec![],
                last_file_transaction: None,
                shelves: vec![Shelf {
                    id: identifier(),
                    name: "Documents".into(),
                    items: vec![item],
                }],
            })
            .unwrap();
        let reopened = f.store();
        assert_eq!(reopened.library.shelves.len(), 1);
        assert_eq!(
            fs::read_to_string(&reopened.library.shelves[0].items[0].path).unwrap(),
            "hello\nworld"
        );
    }
    #[test]
    fn owned_flag_cannot_delete_an_external_file() {
        let f = Fixture::new();
        let source = f.0.join("keep.txt");
        fs::write(&source, "keep").unwrap();
        let store = f.store();
        let mut item = store.file(&source, false).unwrap();
        item.owned = true;
        store.remove_owned(&item);
        assert!(source.exists());
    }
    #[test]
    fn recursive_copy_into_library_is_rejected() {
        let f = Fixture::new();
        let store = f.store();
        assert!(store.file(&f.0, true).is_err());
        assert_eq!(fs::read_dir(store.root.join("items")).unwrap().count(), 0);
    }
    #[test]
    fn removing_owned_folder_preserves_a_child_referenced_by_another_shelf() {
        let f = Fixture::new();
        let mut store = f.store();
        let source = f.0.join("folder");
        fs::create_dir(&source).unwrap();
        fs::write(source.join("child.txt"), b"keep").unwrap();
        let folder = store.file(&source, true).unwrap();
        let child = store
            .file(&Path::new(&folder.path).join("child.txt"), false)
            .unwrap();
        store.library.shelves.push(Shelf {
            id: "other".into(),
            name: "Other".into(),
            items: vec![child.clone()],
        });
        store.library.shelves.push(Shelf {
            id: "owner".into(),
            name: "Owner".into(),
            items: vec![folder.clone()],
        });
        let mut next = store.library.clone();
        next.shelves.retain(|s| s.id != "owner");
        store.save(next).unwrap();
        store.remove_owned(&folder);
        assert_eq!(fs::read(&child.path).unwrap(), b"keep");
        assert_eq!(store.library.retired.len(), 1);
        let mut next = store.library.clone();
        next.shelves.clear();
        store.save(next).unwrap();
        store.cleanup_retired(u64::MAX).unwrap();
        assert!(!Path::new(&folder.path).exists());
        assert_eq!(fs::read(source.join("child.txt")).unwrap(), b"keep");
    }
    #[cfg(unix)]
    #[test]
    fn copied_folder_preserves_links_without_copying_or_deleting_their_targets() {
        let f = Fixture::new();
        let store = f.store();
        let source = f.0.join("folder");
        fs::create_dir(&source).unwrap();
        let external = f.0.join("external.txt");
        fs::write(&external, b"keep").unwrap();
        std::os::unix::fs::symlink(&external, source.join("linked.txt")).unwrap();
        let item = store.file(&source, true).unwrap();
        assert!(
            fs::symlink_metadata(Path::new(&item.path).join("linked.txt"))
                .unwrap()
                .file_type()
                .is_symlink()
        );
        store.remove_owned(&item);
        assert_eq!(fs::read(external).unwrap(), b"keep");
    }
    #[test]
    fn corrupt_library_is_not_silently_reset() {
        let f = Fixture::new();
        let store = f.store();
        fs::write(store.root.join("library.json"), "broken").unwrap();
        assert!(Storage::open(store.root).is_err());
    }
    #[test]
    fn failed_save_does_not_replace_memory() {
        let f = Fixture::new();
        let mut store = f.store();
        fs::create_dir(store.root.join("library.tmp")).unwrap();
        assert!(store
            .save(Library {
                settings: Settings::default(),
                retired: vec![],
                last_file_transaction: None,
                shelves: vec![Shelf {
                    id: identifier(),
                    name: "New".into(),
                    items: vec![]
                }]
            })
            .is_err());
        assert!(store.library.shelves.is_empty());
    }
    #[test]
    fn dropped_copy_survives_restart_and_grace_period() {
        let f = Fixture::new();
        let mut store = f.store();
        let item = store.text("receiver still needs this").unwrap();
        let mut library = Library::default();
        library.settings.remove_after_drag_out = true;
        library.shelves.push(Shelf {
            id: "shelf".into(),
            name: "Shelf".into(),
            items: vec![item.clone()],
        });
        library.finish_drag("shelf", &[item.id.clone()], true, 100);
        store.save(library).unwrap();
        let mut reopened = f.store();
        reopened.cleanup_retired(159).unwrap();
        assert!(Path::new(&item.path).exists());
        reopened.cleanup_retired(160).unwrap();
        assert!(!Path::new(&item.path).exists());
        assert!(f.store().library.retired.is_empty());
    }
    #[test]
    fn failed_retirement_save_keeps_copy_on_disk() {
        let f = Fixture::new();
        let mut store = f.store();
        let item = store.text("keep").unwrap();
        store.library.retired.push(RetiredItem {
            item: item.clone(),
            delete_after: 100,
        });
        fs::create_dir(store.root.join("library.tmp")).unwrap();
        assert!(store.cleanup_retired(100).is_err());
        assert!(Path::new(&item.path).exists());
    }
}
