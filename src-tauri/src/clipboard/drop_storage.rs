use super::{
    database::Database,
    model::{Capture, Settings},
};
use base64::Engine;
use serde::Deserialize;
use std::{
    fs,
    path::{Path, PathBuf},
};

#[derive(Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct DropContent {
    pub files: Vec<String>,
    pub png: String,
    pub width: u32,
    pub height: u32,
    pub text: String,
    pub url: String,
    pub source: String,
    pub source_id: String,
}

/// Stage incomplete copies outside managed storage so retention cannot delete
/// an import in progress. This guard removes partial copies on failure.
pub struct PreparedDrop {
    staging: PathBuf,
    capture: Capture,
}
impl Drop for PreparedDrop {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.staging);
    }
}
impl PreparedDrop {
    pub fn prepare(root: &Path, content: DropContent) -> Result<Self, String> {
        fs::create_dir_all(root.join("staging")).map_err(|e| e.to_string())?;
        let staging = root.join("staging").join(format!(
            "drop-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|e| e.to_string())?
                .as_nanos()
        ));
        fs::create_dir(&staging).map_err(|e| e.to_string())?;
        let mut prepared = Self {
            staging,
            capture: Capture {
                dropped: true,
                source: if content.source.is_empty() {
                    "Drag and drop".into()
                } else {
                    content.source
                },
                source_id: content.source_id,
                ..Capture::default()
            },
        };
        if !content.files.is_empty() {
            let destination_root = fs::canonicalize(root).map_err(|e| e.to_string())?;
            for (index, filename) in content.files.iter().enumerate() {
                let source = fs::canonicalize(filename)
                    .map_err(|e| format!("Could not read {filename}: {e}"))?;
                if destination_root.starts_with(&source) {
                    return Err(
                        "Cannot copy a folder containing Tooki's clipboard storage into itself."
                            .into(),
                    );
                }
                let name = source.file_name().ok_or("This file has no name.")?;
                let directory = prepared.staging.join(index.to_string());
                fs::create_dir(&directory).map_err(|e| e.to_string())?;
                let target = directory.join(name);
                crate::file_copy::copy_tree(&source, &target)?;
                prepared.capture.bytes += file_bytes(&target)?;
                prepared
                    .capture
                    .files
                    .push(target.to_string_lossy().into_owned());
            }
        } else if !content.png.is_empty() {
            if content.width == 0
                || content.height == 0
                || u64::from(content.width) * u64::from(content.height) > 100_000_000
            {
                return Err("The dropped image has unsupported dimensions.".into());
            }
            if content.png.len() > 45 * 1024 * 1024 {
                return Err("This image exceeds the 32 MB clipboard limit.".into());
            }
            let bytes = base64::engine::general_purpose::STANDARD
                .decode(content.png)
                .map_err(|e| e.to_string())?;
            if bytes.len() > 32 * 1024 * 1024 || !bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
                return Err("The dropped image is not a supported PNG.".into());
            }
            let path = prepared.staging.join("image.png");
            fs::write(&path, &bytes).map_err(|e| e.to_string())?;
            prepared.capture.image = path.to_string_lossy().into_owned();
            prepared.capture.width = content.width;
            prepared.capture.height = content.height;
            prepared.capture.bytes = bytes.len() as u64;
        } else {
            let text = if content.url.is_empty() {
                content.text
            } else {
                content.url
            };
            if text.is_empty() {
                return Err(
                    "This app did not provide files, an image, text, or a link to drop.".into(),
                );
            }
            if text.len() > 4 * 1024 * 1024 {
                return Err("This text exceeds the 4 MB clipboard limit.".into());
            }
            prepared.capture.bytes = text.len() as u64;
            prepared.capture.text = text;
        }
        Ok(prepared)
    }

    /// Publish files and their references while holding the database lock.
    pub fn record(mut self, db: &Database, settings: &Settings) -> Result<String, String> {
        if !self.capture.image.is_empty() && settings.max_images == 0 {
            return Err("Enable image history before adding an image.".into());
        }
        if !self.capture.files.is_empty() {
            let folder = db
                .root
                .join("files")
                .join(self.staging.file_name().ok_or("Missing drop directory")?);
            fs::create_dir_all(db.root.join("files")).map_err(|e| e.to_string())?;
            fs::rename(&self.staging, &folder).map_err(|e| e.to_string())?;
            for file in &mut self.capture.files {
                let relative = Path::new(file)
                    .strip_prefix(&self.staging)
                    .map_err(|e| e.to_string())?;
                *file = folder.join(relative).to_string_lossy().into_owned();
            }
        }
        let result = db.record(std::mem::take(&mut self.capture), settings);
        // A successful write followed by a trim error must retain its files.
        if result.is_err() {
            let _ = clean_files(db);
        }
        result
    }
}

fn file_bytes(path: &Path) -> Result<u64, String> {
    let metadata = fs::symlink_metadata(path).map_err(|e| e.to_string())?;
    if !metadata.is_dir() {
        return Ok(metadata.len());
    }
    fs::read_dir(path)
        .map_err(|e| e.to_string())?
        .try_fold(0, |total, entry| {
            let entry = entry.map_err(|e| e.to_string())?;
            Ok(total + file_bytes(&entry.path())?)
        })
}

pub fn clean_files(db: &Database) -> Result<(), String> {
    let mut statement = db
        .connection
        .prepare("SELECT value FROM clips, json_each(payload, '$.files')")
        .map_err(|e| e.to_string())?;
    let paths = statement
        .query_map([], |r| r.get::<_, String>(0))
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    if let Ok(entries) = fs::read_dir(db.root.join("files")) {
        for entry in entries {
            let entry = entry.map_err(|e| e.to_string())?;
            let folder = entry.path();
            if !paths.iter().any(|p| Path::new(p).starts_with(&folder)) {
                // Delete only direct children of our managed directory.
                if entry.file_type().map_err(|e| e.to_string())?.is_dir() {
                    fs::remove_dir_all(folder).map_err(|e| e.to_string())?;
                } else {
                    fs::remove_file(folder).map_err(|e| e.to_string())?;
                }
            }
        }
    }
    Ok(())
}
