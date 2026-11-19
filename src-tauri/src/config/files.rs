use serde_json::Value;
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
};
static NEXT: AtomicU64 = AtomicU64::new(1);
pub fn read(path: &Path) -> Result<Option<Vec<u8>>, String> {
    match fs::read(path) {
        Ok(bytes) if bytes.len() <= 8 * 1024 * 1024 => Ok(Some(bytes)),
        Ok(_) => Err(format!("{} exceeds 8 MB", path.display())),
        Err(e)
            if e.kind() == std::io::ErrorKind::NotFound && fs::symlink_metadata(path).is_err() =>
        {
            Ok(None)
        }
        Err(e) => Err(format!("{}: {e}", path.display())),
    }
}
pub fn json(path: &Path) -> Result<Option<Value>, String> {
    read(path)?
        .map(|b| serde_json::from_slice(&b).map_err(|e| format!("{}: {e}", path.display())))
        .transpose()
}
pub fn directory(path: &Path) -> Result<(), String> {
    fs::create_dir_all(path).map_err(|e| e.to_string())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).map_err(|e| e.to_string())?;
    }
    Ok(())
}
// Replace the symlink's target, never a user's dotfiles link.
fn target(path: &Path) -> Result<PathBuf, String> {
    if fs::symlink_metadata(path).is_ok_and(|m| m.file_type().is_symlink()) {
        fs::canonicalize(path).map_err(|e| format!("Cannot resolve {}: {e}", path.display()))
    } else {
        Ok(path.to_path_buf())
    }
}
pub fn write(path: &Path, value: &Value, expected: Option<&[u8]>) -> Result<(), String> {
    let path = target(path)?;
    let parent = path.parent().ok_or("Missing configuration directory")?;
    directory(parent)?;
    let temp = parent.join(format!(
        ".tooki-{}-{}.tmp",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    let result = (|| {
        let mut options = fs::OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let mut file = options.open(&temp).map_err(|e| e.to_string())?;
        file.write_all(&serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
        file.sync_all().map_err(|e| e.to_string())?;
        if read(&path)?.as_deref() != expected {
            return Err(format!(
                "{} changed on disk. Reload before saving.",
                path.display()
            ));
        }
        fs::rename(&temp, &path).map_err(|e| e.to_string())
    })();
    let _ = fs::remove_file(temp);
    result
}
pub fn entries(root: &Path) -> Result<Vec<PathBuf>, String> {
    if !root.exists() && fs::symlink_metadata(root).is_err() {
        return Ok(Vec::new());
    }
    let mut paths = Vec::new();
    for entry in fs::read_dir(root).map_err(|e| e.to_string())? {
        let path = entry.map_err(|e| e.to_string())?.path();
        if path.extension().is_some_and(|e| e == "json") {
            paths.push(path);
        }
    }
    paths.sort();
    Ok(paths)
}
pub fn safe_id(id: &str) -> Result<(), String> {
    if id.is_empty()
        || id.len() > 100
        || !id
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b"-_.".contains(&c))
        || id == "."
        || id == ".."
    {
        return Err(
            "Use letters, numbers, dots, hyphens or underscores for the identifier.".into(),
        );
    }
    Ok(())
}
