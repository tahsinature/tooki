use super::*;
use sha2::{Digest, Sha256};
use tauri::Emitter;
fn fingerprint(root: &Path) -> Result<Vec<u8>, String> {
    let mut hash = Sha256::new();
    let mut paths = vec![root.join("settings.json"), root.join("shortcuts.json")];
    paths.extend(files::entries(&root.join("themes"))?);
    paths.extend(files::entries(&root.join("snippets"))?);
    for path in paths {
        hash.update(path.to_string_lossy().as_bytes());
        if let Some(bytes) = files::read(&path)? {
            hash.update(bytes);
        }
    }
    Ok(hash.finalize().to_vec())
}
pub fn start(app: &tauri::AppHandle) {
    let app = app.clone();
    std::thread::spawn(move || {
        let root = get(&app).root.clone();
        let mut previous = None;
        let mut reported = String::new();
        loop {
            std::thread::sleep(std::time::Duration::from_secs(2));
            match fingerprint(&root) {
                Ok(next) if previous.as_ref() != Some(&next) => {
                    previous = Some(next);
                    let handle = app.clone();
                    let _ = app.run_on_main_thread(move || reload(&handle));
                    reported.clear();
                }
                Err(error) if error != reported => {
                    let _ = app.emit("portable-config-error", &error);
                    reported = error;
                }
                _ => {}
            }
        }
    });
}
fn reload(app: &tauri::AppHandle) {
    // Each feature retains its last valid runtime settings if its section is invalid.
    let mut errors = Vec::new();
    for result in [
        crate::launcher_shortcut::reload(app),
        crate::applications::preferences::reload(app),
        crate::hyper::reload_preferences(app),
        crate::keep_awake::reload_preferences(app),
        crate::extensions::shelferry::reload_preferences(app),
        crate::clipboard::preferences::reload(app),
    ] {
        if let Err(error) = result {
            errors.push(error);
        }
    }
    crate::general_settings::initialize(app);
    let _ = app.emit("portable-config-changed", ());
    let handle = app.clone();
    tauri::async_runtime::spawn(async move {
        match crate::snippets::configure(&handle).await {
            Ok(_) => {
                let _ = handle.emit("snippets-changed", ());
            }
            Err(error) => {
                errors.push(error);
            }
        }
        let _ = handle.emit("portable-config-error", errors.join("\n"));
    });
}
