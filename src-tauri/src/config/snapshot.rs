//! The configuration currently loaded by Tooki. Disk changes enter only on reload.
use super::files;
use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
};

pub const GROUPS: [&str; 4] = ["settings.json", "shortcuts.json", "themes", "snippets"];
#[derive(Clone, Default)]
pub struct Snapshot {
    bytes: BTreeMap<PathBuf, Result<Option<Vec<u8>>, String>>,
    directories: BTreeMap<PathBuf, Result<Vec<PathBuf>, String>>,
}
impl Snapshot {
    pub fn load(root: &Path) -> Self {
        let mut snapshot = Self::default();
        for group in GROUPS {
            snapshot.reload(root, group);
        }
        snapshot
    }
    pub fn reload(&mut self, root: &Path, group: &str) {
        let path = root.join(group);
        if group.ends_with(".json") {
            self.bytes.insert(path.clone(), files::read(&path));
        } else {
            self.bytes
                .retain(|key, _| key.parent() != Some(path.as_path()));
            let entries = files::entries(&path);
            if let Ok(entries) = &entries {
                for file in entries {
                    self.bytes.insert(file.clone(), files::read(file));
                }
            }
            self.directories.insert(path, entries);
        }
    }
    pub fn replace_group(&mut self, source: &Self, root: &Path, group: &str) {
        let path = root.join(group);
        self.bytes
            .retain(|key, _| key != &path && key.parent() != Some(path.as_path()));
        for (key, value) in &source.bytes {
            if key == &path || key.parent() == Some(path.as_path()) {
                self.bytes.insert(key.clone(), value.clone());
            }
        }
        if let Some(entries) = source.directories.get(&path) {
            self.directories.insert(path, entries.clone());
        }
    }
    pub fn read(&self, path: &Path) -> Result<Option<Vec<u8>>, String> {
        self.bytes.get(path).cloned().unwrap_or(Ok(None))
    }
    pub fn entries(&self, path: &Path) -> Result<Vec<PathBuf>, String> {
        self.directories.get(path).cloned().unwrap_or(Ok(vec![]))
    }
    pub fn saved(&mut self, path: &Path, bytes: Option<Vec<u8>>) {
        if let Some(Ok(entries)) = path.parent().and_then(|p| self.directories.get_mut(p)) {
            entries.retain(|entry| entry != path);
            if bytes.is_some() {
                entries.push(path.into());
                entries.sort();
            }
        }
        self.bytes.insert(path.into(), Ok(bytes));
    }
}
