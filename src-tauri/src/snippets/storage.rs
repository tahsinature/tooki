use super::model::*;
use crate::config::{files, Config};
use serde_json::json;
use sha2::{Digest, Sha256};
#[cfg(test)]
use std::path::Path;
use std::path::PathBuf;
pub struct Storage {
    root: PathBuf,
    config: Config,
}
impl Storage {
    pub fn loaded(config: Config) -> Self {
        Self {
            root: config.root.clone(),
            config,
        }
    }
    #[cfg(test)]
    pub fn open(root: &Path, legacy: &Path, import_legacy: bool) -> Result<Self, String> {
        Self::open_config(Config::new(root.into(), legacy.into(), import_legacy))
    }
    pub fn open_config(config: Config) -> Result<Self, String> {
        let root = &config.root;
        let legacy = &config.legacy;
        let import_legacy = config.import_legacy;
        let directory = root.join("snippets");
        // The old SQLite database stays intact. Only a new destination is populated.
        if !directory.exists() {
            let old = legacy.join("snippets/snippets.sqlite3");
            let (records, preferences) = if old.exists() && import_legacy {
                let db = super::legacy::Storage::read_only(&old)?;
                (db.list()?, db.preferences()?)
            } else {
                (vec![], Preferences::default())
            };
            let stage = root.join(".snippets-migration");
            files::directory(&stage)?;
            for record in &records {
                record.validate()?;
                let path = stage.join(filename(&record.definition.id));
                let before = files::read(&path)?;
                files::write(&path, &json!(record), before.as_deref())?;
            }
            validate_conflicts(&records)?;
            config.migrate(
                "settings.json",
                "snippets",
                preferences,
                Preferences::default(),
            )?;
            std::fs::rename(stage, &directory).map_err(|e| e.to_string())?;
            config.refresh_group("snippets");
        }
        // Reads use the loaded snapshot. Explicit reload validates repaired files.
        Ok(Self {
            root: root.into(),
            config,
        })
    }
    pub fn list(&self) -> Result<Vec<Record>, String> {
        let mut records = vec![];
        for path in self.config.entries(&self.root.join("snippets"))? {
            let bytes = self
                .config
                .bytes(&path)?
                .ok_or("Snippet disappeared during reload")?;
            let mut record: Record =
                serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
            record
                .validate()
                .map_err(|e| format!("{}: {e}", path.display()))?;
            if path.file_name().and_then(|n| n.to_str())
                != Some(filename(&record.definition.id).as_str())
            {
                return Err(format!(
                    "Snippet filename does not match its identifier: {}",
                    path.display()
                ));
            }
            record.revision = revision(&bytes);
            records.push(record);
        }
        if records.len() > 1000 {
            return Err("This version supports up to 1,000 snippets.".into());
        }
        validate_conflicts(&records)?;
        Ok(records)
    }
    pub fn save(&mut self, mut record: Record) -> Result<Record, String> {
        let _writes = crate::config::WRITES.lock().map_err(|e| e.to_string())?;
        record.validate()?;
        let path = self
            .root
            .join("snippets")
            .join(filename(&record.definition.id));
        let before = self.config.bytes(&path)?;
        if before.as_deref().map(revision).unwrap_or(0) != record.revision {
            return Err("This snippet changed on disk. Reopen it before saving.".into());
        }
        let mut all = self.list()?;
        all.retain(|r| r.definition.id != record.definition.id);
        if all.len() >= 1000 {
            return Err("This version supports up to 1,000 snippets.".into());
        }
        all.push(record.clone());
        validate_conflicts(&all)?;
        // Revision is a content fingerprint, so edits from two computers with equal
        // counters still conflict. Keep runtime fingerprints out of portable files.
        record.revision = 0;
        self.config
            .write_file(&path, &json!(record), before.as_deref())?;
        let bytes = self
            .config
            .bytes(&path)?
            .ok_or("Snippet disappeared after saving")?;
        record.revision = revision(&bytes);
        Ok(record)
    }
    pub fn delete(&mut self, id: &str, expected: i64) -> Result<(), String> {
        let _writes = crate::config::WRITES.lock().map_err(|e| e.to_string())?;
        let path = self.root.join("snippets").join(filename(id));
        if self.config.bytes(&path)?.as_deref().map(revision) != Some(expected) {
            return Err("This snippet changed on disk. Reopen it before deleting.".into());
        }
        let before = self.config.bytes(&path)?;
        self.config.remove_file(&path, before.as_deref())
    }
    #[cfg(test)]
    pub fn reload(&self) {
        self.config.refresh_group("snippets");
        self.config.refresh_group("settings.json");
    }
    pub fn preferences(&self) -> Result<Preferences, String> {
        let preferences: Preferences =
            self.config
                .read("settings.json", "snippets", Preferences::default())?;
        validate_preferences(&preferences)?;
        Ok(preferences)
    }
    pub fn set_preferences(&self, preferences: &Preferences) -> Result<(), String> {
        validate_preferences(preferences)?;
        self.config.set("settings.json", "snippets", preferences)
    }
}
pub(super) fn validate_preferences(value: &Preferences) -> Result<(), String> {
    if value.excluded_apps.len() > 200
        || value
            .excluded_apps
            .iter()
            .any(|id| id.len() > 200 || id.contains(char::is_whitespace))
    {
        return Err("Enter valid application bundle identifiers, one per line.".into());
    }
    Ok(())
}
fn revision(bytes: &[u8]) -> i64 {
    let digest = Sha256::digest(bytes);
    (u64::from_be_bytes(digest[..8].try_into().unwrap()) & ((1 << 53) - 1)) as i64
}
fn filename(id: &str) -> String {
    // Existing identifiers were unrestricted. Hash only unsafe IDs to preserve them
    // without permitting path traversal; ordinary UUIDs stay human-readable.
    if files::safe_id(id).is_ok() {
        format!("{id}.json")
    } else {
        format!(
            "{}.json",
            Sha256::digest(id.as_bytes())
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect::<String>()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn temp() -> PathBuf {
        std::env::temp_dir().join(format!(
            "tooki-snippet-files-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ))
    }
    fn record() -> Record {
        serde_json::from_value(json!({"definition":{"schemaVersion":1,"id":"test","name":"Test","description":"","collection":"","kind":"text","template":"Hello","inputs":[],"capabilities":["local"]},"configuration":{"enabled":true,"automatic":false,"instant":false,"trigger":";test","defaults":{},"choices":{},"values":{}},"revision":0})).unwrap()
    }
    #[test]
    fn external_edits_and_deletions_are_visible_and_stale_writes_fail() {
        let root = temp();
        files::directory(&root).unwrap();
        let mut store = Storage::open(&root, &root.join("old"), false).unwrap();
        let saved = store.save(record()).unwrap();
        let path = root.join("snippets/test.json");
        let mut external = files::json(&path).unwrap().unwrap();
        external["definition"]["template"] = json!("Edited elsewhere");
        let bytes = files::read(&path).unwrap();
        files::write(&path, &external, bytes.as_deref()).unwrap();
        assert_eq!(store.list().unwrap()[0].definition.template, "Hello");
        assert!(store.save(saved.clone()).is_err());
        assert!(store.delete("test", saved.revision).is_err());
        store.reload();
        assert_eq!(
            store.list().unwrap()[0].definition.template,
            "Edited elsewhere"
        );
        assert!(store.save(saved.clone()).is_err());
        assert!(store.delete("test", saved.revision).is_err());
        let current = store.list().unwrap().remove(0);
        store.delete("test", current.revision).unwrap();
        assert!(store.list().unwrap().is_empty());
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn repaired_files_recover_without_reopening_storage() {
        let root = temp();
        files::directory(&root.join("snippets")).unwrap();
        let path = root.join("snippets/test.json");
        std::fs::write(&path, b"broken").unwrap();
        let store = Storage::open(&root, &root.join("old"), false).unwrap();
        assert!(store.list().is_err());
        files::write(&path, &json!(record()), Some(b"broken")).unwrap();
        assert!(store.list().is_err());
        store.reload();
        assert_eq!(store.list().unwrap().len(), 1);
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn sqlite_migration_preserves_original_and_does_not_resurrect_deleted_entries() {
        let root = temp();
        let legacy = root.join("legacy");
        files::directory(&legacy.join("snippets")).unwrap();
        let path = legacy.join("snippets/snippets.sqlite3");
        let mut old = super::super::legacy::Storage::open(&path).unwrap();
        old.save(record()).unwrap();
        drop(old);
        let before = std::fs::read(&path).unwrap();
        let mut store = Storage::open(&root, &legacy, true).unwrap();
        let saved = store.list().unwrap().remove(0);
        store.delete("test", saved.revision).unwrap();
        drop(store);
        assert!(Storage::open(&root, &legacy, true)
            .unwrap()
            .list()
            .unwrap()
            .is_empty());
        assert_eq!(before, std::fs::read(path).unwrap());
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn swift_import_converts_supported_fields_and_disables_unsupported_or_conflicting_entries() {
        let root = temp();
        files::directory(&root).unwrap();
        let mut store = Storage::open(&root, &root.join("old"), false).unwrap();
        store.save(record()).unwrap();
        let source = root.join("snippets.json");
        let value = json!([
            {"id":"one","name":"Today","text":"{date}","keyword":"$today"},
            {"id":"two","name":"Cursor","text":"Hi {cursor}","keyword":";hi"},
            {"id":"three","name":"Conflict","text":"other","keyword":";test"},
            {"id":"four","name":"Trigger","text":"value","keyword":"word"}
        ]);
        files::write(&source, &value, None).unwrap();
        super::super::migration::import_swift(&root, &source, &mut store).unwrap();
        super::super::migration::import_swift(&root, &source, &mut store).unwrap();
        let records = store.list().unwrap();
        assert_eq!(records.len(), 5);
        let today = records
            .iter()
            .find(|r| r.definition.id == "swift-one")
            .unwrap();
        assert_eq!(today.definition.template, "{{date}}");
        assert!(today.configuration.enabled);
        assert_eq!(
            records.iter().filter(|r| !r.configuration.enabled).count(),
            3
        );
        assert_eq!(files::json(&source).unwrap().unwrap(), value);
        std::fs::remove_dir_all(root).unwrap();
    }
}
