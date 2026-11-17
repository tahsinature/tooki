use super::Application;
use std::{
    collections::{HashMap, HashSet},
    path::{Path, PathBuf},
};
fn entry(source: &str, desktop: &str) -> Option<String> {
    let mut fields = HashMap::new();
    let mut section = false;
    for line in source.lines().map(str::trim) {
        if line.starts_with('[') {
            section = line == "[Desktop Entry]";
        } else if section && !line.starts_with('#') {
            if let Some((key, value)) = line.split_once('=') {
                fields.insert(key.trim(), value.trim());
            }
        }
    }
    if fields.get("Type") != Some(&"Application")
        || ["Hidden", "NoDisplay"]
            .iter()
            .any(|key| fields.get(key) == Some(&"true"))
    {
        return None;
    }
    let environments: Vec<_> = desktop.split(':').collect();
    if let Some(only) = fields.get("OnlyShowIn") {
        if !only.split(';').any(|env| environments.contains(&env)) {
            return None;
        }
    }
    if let Some(excluded) = fields.get("NotShowIn") {
        if excluded
            .split(';')
            .filter(|s| !s.is_empty())
            .any(|env| environments.contains(&env))
        {
            return None;
        }
    }
    if !fields.contains_key("Exec") && fields.get("DBusActivatable") != Some(&"true") {
        return None;
    }
    fields
        .get("Name")
        .filter(|name| !name.is_empty())
        .map(|name| name.to_string())
}
fn collect(
    root: &Path,
    dir: &Path,
    seen: &mut HashSet<String>,
    apps: &mut Vec<Application>,
    desktop: &str,
) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for file in entries.flatten() {
        let path = file.path();
        if file.file_type().is_ok_and(|kind| kind.is_dir()) {
            collect(root, &path, seen, apps, desktop);
        } else if path.extension().is_some_and(|ext| ext == "desktop") {
            let id = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('/', "-");
            // Higher-priority Hidden entries also mask system entries.
            if !seen.insert(id) {
                continue;
            }
            if let Ok(source) = std::fs::read_to_string(&path) {
                if let Some(name) = entry(&source, desktop) {
                    apps.push(Application {
                        id: path.to_string_lossy().into_owned(),
                        name,
                        icon: None,
                    });
                }
            }
        }
    }
}
pub fn scan() -> Result<Vec<Application>, String> {
    let home = std::env::var("HOME").unwrap_or_default();
    let mut roots = vec![PathBuf::from(
        std::env::var("XDG_DATA_HOME").unwrap_or(format!("{home}/.local/share")),
    )];
    roots.extend(std::env::split_paths(
        &std::env::var_os("XDG_DATA_DIRS").unwrap_or_else(|| "/usr/local/share:/usr/share".into()),
    ));
    let mut apps = Vec::new();
    let mut seen = HashSet::new();
    let desktop = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    for root in roots {
        let root = root.join("applications");
        collect(&root, &root, &mut seen, &mut apps, &desktop);
    }
    Ok(apps)
}
pub fn launch(id: &str) -> Result<(), String> {
    let output = std::process::Command::new("gio")
        .args(["launch", id])
        .output()
        .map_err(|e| format!("Could not launch application with gio: {e}"))?;
    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().into())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn desktop_visibility() {
        let valid = "[Desktop Entry]\nType=Application\nName=Editor\nExec=editor %U\n";
        assert_eq!(entry(valid, "GNOME"), Some("Editor".into()));
        assert_eq!(entry(&format!("{valid}Hidden=true"), "GNOME"), None);
        assert_eq!(entry(&format!("{valid}OnlyShowIn=KDE;"), "GNOME"), None);
        assert_eq!(entry(&format!("{valid}NotShowIn=GNOME;"), "GNOME"), None);
    }
}

pub fn location(id: &str) -> String {
    id.into()
}
pub fn reveal(id: &str) -> Result<(), String> {
    let parent = Path::new(id)
        .parent()
        .ok_or("Application location is unavailable")?;
    std::process::Command::new("xdg-open")
        .arg(parent)
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
fn software_manager() -> Option<(&'static str, &'static str)> {
    let paths = std::env::var_os("PATH")?;
    for (name, flag) in [
        ("gnome-software", "--details"),
        ("plasma-discover", "--application"),
    ] {
        if std::env::split_paths(&paths).any(|path| path.join(name).is_file()) {
            return Some((name, flag));
        }
    }
    None
}
pub fn can_uninstall(_: &str) -> bool {
    software_manager().is_some()
}
pub fn uninstall(id: &str) -> Result<(), String> {
    let (program, flag) =
        software_manager().ok_or("No supported system software manager was found.")?;
    let desktop_id = Path::new(id).file_name().ok_or("Invalid desktop entry")?;
    std::process::Command::new(program)
        .arg(flag)
        .arg(desktop_id)
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
