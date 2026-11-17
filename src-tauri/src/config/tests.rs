use super::*;
fn temp() -> PathBuf {
    std::env::temp_dir().join(format!(
        "tooki-config-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ))
}
#[test]
fn migration_keeps_existing_settings_and_preserves_unrelated_sections() {
    let root = temp();
    let config = Config {
        root: root.clone(),
        legacy: root.join("legacy"),
        import_legacy: true,
    };
    config
        .set("settings.json", "appearance", &json!({"selected":"mine"}))
        .unwrap();
    config
        .migrate(
            "settings.json",
            "appearance",
            json!({"selected":"old"}),
            json!({}),
        )
        .unwrap();
    config.set("settings.json", "hyperEnabled", &false).unwrap();
    assert_eq!(
        config
            .read::<Value>("settings.json", "appearance", Value::Null)
            .unwrap()["selected"],
        "mine"
    );
    std::fs::remove_dir_all(root).unwrap();
}
#[test]
fn invalid_and_concurrently_changed_files_are_not_overwritten() {
    let root = temp();
    files::directory(&root).unwrap();
    let path = root.join("settings.json");
    std::fs::write(&path, b"broken").unwrap();
    let config = Config {
        root: root.clone(),
        legacy: root.clone(),
        import_legacy: false,
    };
    assert!(config.set("settings.json", "x", &true).is_err());
    assert!(files::write(&path, &json!({}), Some(b"old")).is_err());
    assert_eq!(std::fs::read(&path).unwrap(), b"broken");
    std::fs::remove_dir_all(root).unwrap();
}
#[cfg(unix)]
#[test]
fn writes_preserve_dotfile_symlinks() {
    let root = temp();
    files::directory(&root).unwrap();
    let target = root.join("managed.json");
    let link = root.join("settings.json");
    std::fs::write(&target, b"{}").unwrap();
    std::os::unix::fs::symlink(&target, &link).unwrap();
    files::write(&link, &json!({"version":1}), Some(b"{}")).unwrap();
    assert!(std::fs::symlink_metadata(&link)
        .unwrap()
        .file_type()
        .is_symlink());
    assert_eq!(files::json(&target).unwrap().unwrap()["version"], 1);
    std::fs::remove_dir_all(root).unwrap();
}

#[test]
fn invalid_interface_settings_are_rejected_before_application() {
    assert!(frontend::validate_interface(&json!(false)).is_err());
    assert!(frontend::validate_interface(&json!({"compactLauncher":"yes"})).is_err());
    assert!(frontend::validate_interface(&json!({"notesFont":"invalid"})).is_err());
    assert!(
        frontend::validate_interface(&json!({"compactLauncher":false,"notesFont":"mono"})).is_ok()
    );
}
