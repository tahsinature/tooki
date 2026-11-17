//! Conversion previews are separate from shelf files. Only an explicit save changes originals.
use super::{model::*, storage::Storage};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    sync::{Mutex, OnceLock},
};
struct Preview {
    item: Item,
    path: PathBuf,
    fingerprint: Vec<u8>,
}
struct Session {
    shelf: String,
    root: PathBuf,
    previews: Vec<Preview>,
}
impl Drop for Session {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}
static SESSIONS: OnceLock<Mutex<HashMap<String, Session>>> = OnceLock::new();
fn sessions() -> &'static Mutex<HashMap<String, Session>> {
    SESSIONS.get_or_init(Default::default)
}
pub(super) fn fingerprint(path: &Path) -> Result<Vec<u8>, String> {
    use std::io::Read;
    let mut file = fs::File::open(path).map_err(|e| e.to_string())?;
    let mut hash = Sha256::new();
    let mut buffer = [0; 65536];
    loop {
        let n = file.read(&mut buffer).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        hash.update(&buffer[..n]);
    }
    Ok(hash.finalize().to_vec())
}
pub fn prepare(store: &Storage, shelf: &str, args: &Value) -> Result<Value, String> {
    let shelf = store
        .library
        .shelves
        .iter()
        .find(|s| s.id == shelf)
        .ok_or("Shelf not found")?;
    let ids = args["items"].as_array().ok_or("Select images to convert")?;
    let items: Vec<_> = shelf
        .items
        .iter()
        .filter(|i| ids.contains(&json!(i.id)))
        .cloned()
        .collect();
    if items.is_empty() {
        return Err("Select images to convert".into());
    }
    let extension = match args["format"].as_str() {
        Some("jpeg") => "jpg",
        Some("png") => "png",
        Some("heif") => "heic",
        _ => return Err("Choose JPEG, PNG or HEIF".into()),
    };
    let size = args["size"].as_u64().unwrap_or(0);
    if ![0, 640, 1280, 1920].contains(&size) {
        return Err("Invalid image size".into());
    }
    let id = identifier();
    let root = store.root.join("conversions").join(&id);
    fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    let mut session = Session {
        shelf: shelf.id.clone(),
        root,
        previews: vec![],
    };
    let mut results = vec![];
    let mut errors = vec![];
    for item in items {
        let outcome = (|| -> Result<(Preview, Value), String> {
            let source = Path::new(&item.path);
            if fs::symlink_metadata(source)
                .map_err(|e| e.to_string())?
                .file_type()
                .is_symlink()
            {
                return Err("Convert the original image, not a symbolic link.".into());
            }
            let before = fingerprint(source)?;
            let dir = session.root.join(&item.id);
            fs::create_dir(&dir).map_err(|e| e.to_string())?;
            let filename = source
                .file_stem()
                .ok_or("Invalid filename")?
                .to_string_lossy();
            let path = dir.join(format!("{filename}.{extension}"));
            crate::platform::shelf::content::convert(
                json!({"source":source,"output":path,"format":args["format"],"size":size,"metadata":args["metadata"].as_bool().unwrap_or(true)}),
            )?;
            if before != fingerprint(source)? {
                return Err("Source changed while converting. Please try again.".into());
            }
            let result = json!({"item":item.id,"name":path.file_name().unwrap().to_string_lossy(),"bytes":path.metadata().map_err(|e|e.to_string())?.len(),"beforeBytes":source.metadata().map_err(|e|e.to_string())?.len(),"image":crate::platform::shelf::content::thumbnail(&path.to_string_lossy())});
            Ok((
                Preview {
                    item: item.clone(),
                    path,
                    fingerprint: before,
                },
                result,
            ))
        })();
        match outcome {
            Ok((preview, result)) => {
                session.previews.push(preview);
                results.push(result);
            }
            Err(error) => errors.push(json!({"name":item.name,"error":error})),
        }
    }
    if results.is_empty() {
        return Err(errors
            .iter()
            .map(|e| {
                format!(
                    "{}: {}",
                    e["name"].as_str().unwrap_or("Image"),
                    e["error"].as_str().unwrap_or("Failed")
                )
            })
            .collect::<Vec<_>>()
            .join("\n"));
    }
    sessions()
        .lock()
        .map_err(|e| e.to_string())?
        .insert(id.clone(), session);
    Ok(json!({"session":id,"results":results,"errors":errors}))
}
pub fn preview_paths(id: &str) -> Result<Vec<PathBuf>, String> {
    let sessions = sessions().lock().map_err(|e| e.to_string())?;
    Ok(sessions
        .get(id)
        .ok_or("Conversion expired")?
        .previews
        .iter()
        .map(|p| p.path.clone())
        .collect())
}
pub fn refresh_preview(id: &str, index: usize) -> Result<Value, String> {
    let sessions = sessions().lock().map_err(|e| e.to_string())?;
    let preview = sessions
        .get(id)
        .and_then(|s| s.previews.get(index))
        .ok_or("Conversion expired")?;
    crate::platform::shelf::content::validate_image(&preview.path)?;
    Ok(
        json!({"bytes":preview.path.metadata().map_err(|e|e.to_string())?.len(),"image":crate::platform::shelf::content::thumbnail(&preview.path.to_string_lossy())}),
    )
}
pub fn discard(id: &str) {
    if let Ok(mut sessions) = sessions().lock() {
        sessions.remove(id);
    }
}
pub fn save(store: &mut Storage, shelf: &str, id: &str, replace: bool) -> Result<Value, String> {
    super::file_transaction::recover(&store.root, &store.library)?;
    let mut sessions = sessions().lock().map_err(|e| e.to_string())?;
    let session = sessions.get(id).ok_or("Conversion expired")?;
    if session.shelf != shelf {
        return Err("This conversion belongs to another shelf".into());
    }
    let mut next = store.library.clone();
    let index = next
        .shelves
        .iter()
        .position(|s| s.id == shelf)
        .ok_or("Shelf not found")?;
    // Validate the entire batch before touching any files.
    for preview in &session.previews {
        crate::platform::shelf::content::validate_image(&preview.path)?;
        if !next.shelves[index]
            .items
            .iter()
            .any(|i| i.id == preview.item.id && i.path == preview.item.path)
        {
            return Err("A source item was removed or renamed. Convert again.".into());
        }
        if fingerprint(Path::new(&preview.item.path))? != preview.fingerprint {
            return Err("A source image changed. Convert again to avoid overwriting edits.".into());
        }
    }
    let mut created = vec![];
    let mut transaction = super::file_transaction::FileTransaction::new(identifier());
    if replace {
        next.last_file_transaction = Some(transaction.id.clone());
    }
    let mut result_ids = vec![];
    let result = (|| -> Result<(), String> {
        for preview in &session.previews {
            if replace {
                let source = PathBuf::from(&preview.item.path);
                let target = source.with_extension(
                    preview
                        .path
                        .extension()
                        .ok_or("Invalid conversion output")?,
                );
                if target != source && target.exists() {
                    return Err(format!("{} already exists", target.display()));
                }
                let staging = source.with_file_name(format!(".tooki-convert-{}", identifier()));
                let backup = source.with_file_name(format!(".tooki-original-{}", identifier()));
                fs::copy(&preview.path, &staging).map_err(|e| e.to_string())?;
                if fingerprint(&source)? != preview.fingerprint {
                    let _ = fs::remove_file(&staging);
                    return Err("Source changed while preparing replacement. Convert again.".into());
                }
                transaction.record(
                    &store.root,
                    super::file_transaction::Replacement {
                        source: source.clone(),
                        target: target.clone(),
                        staging: staging.clone(),
                        backup: backup.clone(),
                        output_hash: fingerprint(&staging)?,
                    },
                )?;
                super::files::rename_without_replacing(&source, &backup)?;
                super::files::rename_without_replacing(&staging, &target)?;
                for s in &mut next.shelves {
                    for item in &mut s.items {
                        if Path::new(&item.path) == source {
                            item.path = target.to_string_lossy().into();
                            item.name = target.file_name().unwrap().to_string_lossy().into();
                        }
                    }
                }
                result_ids.push(preview.item.id.clone());
            } else {
                let mut item = store.file(&preview.path, true)?;
                item.original_path = Some(preview.item.path.clone());
                result_ids.push(item.id.clone());
                created.push(item.clone());
                let at = next.shelves[index]
                    .items
                    .iter()
                    .position(|i| i.id == preview.item.id)
                    .unwrap()
                    + 1;
                next.shelves[index].items.insert(at, item);
            }
        }
        store.save(next)?;
        Ok(())
    })();
    if let Err(error) = result {
        let recovery_error = transaction.finish(&store.root, false).err();
        for item in created {
            store.remove_owned(&item);
        }
        return Err(match recovery_error {
            Some(recovery) => format!("{error}. Recovery needed: {recovery}"),
            None => error,
        });
    }
    transaction.finish(&store.root, true)?;
    sessions.remove(id);
    Ok(json!(result_ids))
}

#[cfg(all(test, target_os = "macos"))]
mod tests {
    use super::*;
    struct Fixture {
        root: PathBuf,
        store: Storage,
        item: Item,
    }
    impl Fixture {
        fn new() -> Self {
            let root = std::env::temp_dir().join(format!("tooki-conversion-{}", identifier()));
            let mut store = Storage::open(root.join("shelf")).unwrap();
            let source = root.join("source.png");
            fs::write(&source, include_bytes!("../../icons/icon.png")).unwrap();
            let item = store.file(&source, false).unwrap();
            store.library.shelves.push(Shelf {
                id: "s".into(),
                name: "Shelf".into(),
                items: vec![item.clone()],
            });
            Self { root, store, item }
        }
        fn prepare(&self) -> String {
            prepare(
                &self.store,
                "s",
                &json!({"items":[self.item.id],"format":"jpeg","size":640,"metadata":false}),
            )
            .unwrap()["session"]
                .as_str()
                .unwrap()
                .into()
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }
    #[test]
    fn preview_and_copy_leave_original_bytes_untouched() {
        let mut f = Fixture::new();
        let original = fs::read(&f.item.path).unwrap();
        let session = f.prepare();
        assert_eq!(fs::read(&f.item.path).unwrap(), original);
        save(&mut f.store, "s", &session, false).unwrap();
        assert_eq!(fs::read(&f.item.path).unwrap(), original);
        assert_eq!(f.store.library.shelves[0].items.len(), 2);
        assert!(f.store.library.shelves[0].items[1].owned);
    }
    #[test]
    fn batch_retains_valid_images_and_refuses_corrupt_edited_previews() {
        let mut f = Fixture::new();
        let original = fs::read(&f.item.path).unwrap();
        let invalid = f.root.join("invalid.png");
        fs::write(&invalid, b"not an image").unwrap();
        let item = f.store.file(&invalid, false).unwrap();
        f.store.library.shelves[0].items.push(item.clone());
        let result = prepare(
            &f.store,
            "s",
            &json!({"items":[f.item.id,item.id],"format":"jpeg","size":640,"metadata":false}),
        )
        .unwrap();
        assert_eq!(result["results"].as_array().unwrap().len(), 1);
        assert_eq!(result["errors"].as_array().unwrap().len(), 1);
        let id = result["session"].as_str().unwrap();
        let paths = preview_paths(id).unwrap();
        fs::write(&paths[0], b"invalid external edit").unwrap();
        assert!(save(&mut f.store, "s", id, true).is_err());
        assert_eq!(fs::read(&f.item.path).unwrap(), original);
        discard(id);
    }
    #[test]
    fn replacement_rejects_changed_sources_and_rolls_back_failed_save() {
        let mut f = Fixture::new();
        let session = f.prepare();
        let original = fs::read(&f.item.path).unwrap();
        fs::write(&f.item.path, b"changed externally").unwrap();
        assert!(save(&mut f.store, "s", &session, true).is_err());
        assert_eq!(fs::read(&f.item.path).unwrap(), b"changed externally");
        fs::write(&f.item.path, &original).unwrap();
        fs::create_dir(f.store.root.join("library.tmp")).unwrap();
        assert!(save(&mut f.store, "s", &session, true).is_err());
        assert_eq!(fs::read(&f.item.path).unwrap(), original);
        assert!(!f.root.join("source.jpg").exists());
        discard(&session);
    }
}
