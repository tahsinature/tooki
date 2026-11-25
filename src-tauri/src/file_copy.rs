//! File copies preserve symbolic links without following directory cycles.
use std::{fs, path::Path};

pub fn copy_tree(source: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::symlink_metadata(source).map_err(|e| e.to_string())?;
    if meta.file_type().is_symlink() {
        let destination = fs::read_link(source).map_err(|e| e.to_string())?;
        #[cfg(unix)]
        return std::os::unix::fs::symlink(destination, target).map_err(|e| e.to_string());
        #[cfg(windows)]
        return if source.is_dir() {
            std::os::windows::fs::symlink_dir(destination, target)
        } else {
            std::os::windows::fs::symlink_file(destination, target)
        }
        .map_err(|e| format!("Could not preserve symbolic link: {e}"));
    }
    if meta.is_dir() {
        fs::create_dir(target).map_err(|e| e.to_string())?;
        for entry in fs::read_dir(source).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            copy_tree(&entry.path(), &target.join(entry.file_name()))?;
        }
    } else if meta.is_file() {
        fs::copy(source, target).map_err(|e| e.to_string())?;
    } else {
        return Err("Only regular files and folders can be copied.".into());
    }
    Ok(())
}
