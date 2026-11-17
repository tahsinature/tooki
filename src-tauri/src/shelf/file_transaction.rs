//! A write-ahead record keeps original images recoverable if Tooki exits during replacement.
use super::{files::rename_without_replacing, model::Library};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
};
#[derive(Serialize, Deserialize)]
pub struct Replacement {
    pub source: PathBuf,
    pub target: PathBuf,
    pub staging: PathBuf,
    pub backup: PathBuf,
    pub output_hash: Vec<u8>,
}
#[derive(Serialize, Deserialize)]
pub struct FileTransaction {
    pub id: String,
    pub replacements: Vec<Replacement>,
}
impl FileTransaction {
    pub fn new(id: String) -> Self {
        Self {
            id,
            replacements: vec![],
        }
    }
    pub fn record(&mut self, root: &Path, replacement: Replacement) -> Result<(), String> {
        self.replacements.push(replacement);
        let temp = root.join("file-transaction.tmp");
        let file = fs::File::create(&temp).map_err(|e| e.to_string())?;
        serde_json::to_writer(&file, self).map_err(|e| e.to_string())?;
        file.sync_all().map_err(|e| e.to_string())?;
        fs::rename(temp, root.join("file-transaction.json")).map_err(|e| e.to_string())
    }
    pub fn finish(&self, root: &Path, committed: bool) -> Result<(), String> {
        for entry in self.replacements.iter().rev() {
            if entry.backup.exists() {
                if committed {
                    fs::remove_file(&entry.backup).map_err(|e| e.to_string())?;
                } else {
                    if entry.target.exists() {
                        if super::conversion::fingerprint(&entry.target)? != entry.output_hash {
                            return Err(format!("A converted file changed during recovery. Original preserved at {}",entry.backup.display()));
                        }
                        fs::remove_file(&entry.target).map_err(|e| e.to_string())?;
                    }
                    rename_without_replacing(&entry.backup, &entry.source)?;
                }
            }
            if entry.staging.exists() {
                fs::remove_file(&entry.staging).map_err(|e| e.to_string())?;
            }
        }
        let path = root.join("file-transaction.json");
        if path.exists() {
            fs::remove_file(path).map_err(|e| e.to_string())?;
        }
        Ok(())
    }
}
pub fn recover(root: &Path, library: &Library) -> Result<(), String> {
    let path = root.join("file-transaction.json");
    if !path.exists() {
        return Ok(());
    }
    let transaction: FileTransaction =
        serde_json::from_slice(&fs::read(path).map_err(|e| e.to_string())?)
            .map_err(|e| format!("Could not read Shelf recovery record: {e}"))?;
    transaction.finish(
        root,
        library.last_file_transaction.as_deref() == Some(&transaction.id),
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn interrupted_replacement_restores_original_before_opening_library() {
        let root = std::env::temp_dir().join(super::super::model::identifier());
        fs::create_dir(&root).unwrap();
        let source = root.join("photo.png");
        let target = root.join("photo.jpg");
        let backup = root.join("backup");
        let staging = root.join("staging");
        fs::write(&backup, b"original").unwrap();
        fs::write(&target, b"converted").unwrap();
        let mut transaction = FileTransaction::new("test".into());
        transaction
            .record(
                &root,
                Replacement {
                    source: source.clone(),
                    target: target.clone(),
                    staging,
                    backup,
                    output_hash: super::super::conversion::fingerprint(&target).unwrap(),
                },
            )
            .unwrap();
        recover(&root, &Library::default()).unwrap();
        assert_eq!(fs::read(source).unwrap(), b"original");
        assert!(!target.exists());
        fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn recovery_preserves_external_edits_and_original_backup() {
        let root = std::env::temp_dir().join(super::super::model::identifier());
        fs::create_dir(&root).unwrap();
        let target = root.join("photo.jpg");
        let backup = root.join("backup");
        fs::write(&target, b"converted").unwrap();
        fs::write(&backup, b"original").unwrap();
        let mut transaction = FileTransaction::new("test".into());
        transaction
            .record(
                &root,
                Replacement {
                    source: root.join("photo.png"),
                    target: target.clone(),
                    staging: root.join("staging"),
                    backup: backup.clone(),
                    output_hash: super::super::conversion::fingerprint(&target).unwrap(),
                },
            )
            .unwrap();
        fs::write(&target, b"external edit").unwrap();
        assert!(recover(&root, &Library::default()).is_err());
        assert_eq!(fs::read(&target).unwrap(), b"external edit");
        assert_eq!(fs::read(backup).unwrap(), b"original");
        fs::remove_dir_all(root).unwrap();
    }
}
