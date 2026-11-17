use super::{model::*, storage::Storage};
use std::{fs, path::Path};

impl Storage {
    /// Rename on disk and update every reference in one saved library. Never replace a file.
    pub fn rename_file(
        &mut self,
        shelf_id: &str,
        item_id: &str,
        proposed: &str,
    ) -> Result<(), String> {
        let name = name(proposed)?;
        if name == "." || name == ".." || name.contains(['/', '\\']) {
            return Err("Use a file name without path separators.".into());
        }
        let item = self
            .library
            .shelves
            .iter()
            .find(|s| s.id == shelf_id)
            .and_then(|s| s.items.iter().find(|i| i.id == item_id))
            .ok_or("Item not found")?;
        let source = Path::new(&item.path).to_path_buf();
        let target = source.parent().ok_or("Invalid file location")?.join(&name);
        if source == target {
            return Ok(());
        }
        if target.exists() {
            return Err("A file with that name already exists.".into());
        }
        // The platform rename must not overwrite a destination created after the check.
        rename_without_replacing(&source, &target)?;
        let mut next = self.library.clone();
        for shelf in &mut next.shelves {
            for item in &mut shelf.items {
                if Path::new(&item.path) == source {
                    item.path = target.to_string_lossy().into();
                    item.name = name.clone();
                }
                if item
                    .original_path
                    .as_deref()
                    .is_some_and(|p| Path::new(p) == source)
                {
                    item.original_path = Some(target.to_string_lossy().into());
                }
            }
        }
        if let Err(error) = self.save(next) {
            rename_without_replacing(&target, &source).map_err(|rollback| {
                format!("{error}. Could not restore original name: {rollback}")
            })?;
            return Err(error);
        }
        Ok(())
    }
    pub fn bytes(&self, filename: &str, bytes: &[u8]) -> Result<Item, String> {
        let id = identifier();
        let dir = self.root.join("items").join(&id);
        fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let path = dir.join(filename);
        if let Err(error) = fs::write(&path, bytes) {
            let _ = fs::remove_dir_all(dir);
            return Err(error.to_string());
        }
        Ok(Item {
            id,
            name: filename.into(),
            path: path.to_string_lossy().into(),
            owned: true,
            original_path: None,
            text: None,
            is_link: false,
        })
    }
}
pub(super) fn rename_without_replacing(source: &Path, target: &Path) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        use std::{ffi::CString, os::unix::ffi::OsStrExt};
        unsafe extern "C" {
            fn renamex_np(
                a: *const std::ffi::c_char,
                b: *const std::ffi::c_char,
                flags: u32,
            ) -> i32;
        }
        let a = CString::new(source.as_os_str().as_bytes()).map_err(|e| e.to_string())?;
        let b = CString::new(target.as_os_str().as_bytes()).map_err(|e| e.to_string())?;
        if unsafe { renamex_np(a.as_ptr(), b.as_ptr(), 4) } != 0 {
            return Err(std::io::Error::last_os_error().to_string());
        }
        Ok(())
    }
    #[cfg(target_os = "linux")]
    {
        use std::{ffi::CString, os::unix::ffi::OsStrExt};
        unsafe extern "C" {
            fn renameat2(
                a: i32,
                b: *const std::ffi::c_char,
                c: i32,
                d: *const std::ffi::c_char,
                flags: u32,
            ) -> i32;
        }
        let a = CString::new(source.as_os_str().as_bytes()).map_err(|e| e.to_string())?;
        let b = CString::new(target.as_os_str().as_bytes()).map_err(|e| e.to_string())?;
        if unsafe { renameat2(-100, a.as_ptr(), -100, b.as_ptr(), 1) } != 0 {
            return Err(std::io::Error::last_os_error().to_string());
        }
        Ok(())
    }
    #[cfg(target_os = "windows")]
    {
        fs::rename(source, target).map_err(|e| e.to_string())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rename_updates_references_and_never_overwrites() {
        let root = std::env::temp_dir().join(identifier());
        let mut store = Storage::open(root.join("store")).unwrap();
        let source = root.join("source.txt");
        fs::write(&source, "keep").unwrap();
        let item = store.file(&source, false).unwrap();
        let shelf = Shelf {
            id: "s".into(),
            name: "S".into(),
            items: vec![item.clone()],
        };
        store.library.shelves.push(shelf);
        store.rename_file("s", &item.id, "renamed.txt").unwrap();
        assert!(!source.exists());
        assert_eq!(
            fs::read_to_string(&store.library.shelves[0].items[0].path).unwrap(),
            "keep"
        );
        fs::write(&source, "other").unwrap();
        assert!(store.rename_file("s", &item.id, "source.txt").is_err());
        assert_eq!(fs::read_to_string(&source).unwrap(), "other");
        assert!(store.rename_file("s", &item.id, "../escape").is_err());
        fs::create_dir(store.root.join("library.tmp")).unwrap();
        assert!(store.rename_file("s", &item.id, "failed.txt").is_err());
        assert!(root.join("renamed.txt").exists());
        fs::remove_dir_all(root).unwrap();
    }
}
