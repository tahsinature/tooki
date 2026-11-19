use super::*;
static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
fn setup() -> Config {
    let root = std::env::temp_dir().join(format!(
        "tooki-reload-{}-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    files::directory(&root).unwrap();
    let config = Config::new(root.clone(), root.join("legacy"), false);
    config.set("settings.json", "hyperEnabled", &false).unwrap();
    config
        .set("shortcuts.json", "launcher", &"CommandOrControl+Space")
        .unwrap();
    config
}
#[test]
fn explicit_reload_keeps_invalid_categories_and_applies_valid_changes() {
    let config = setup();
    let before = report(&config);
    std::fs::write(
        config.root.join("settings.json"),
        br#"{"version":1,"hyperEnabled":true}"#,
    )
    .unwrap();
    std::fs::write(config.root.join("shortcuts.json"), b"broken").unwrap();
    assert!(!config
        .read::<bool>("settings.json", "hyperEnabled", false)
        .unwrap());
    assert!(config.set("settings.json", "hyperEnabled", &true).is_err());
    let result = load(&config, &before).unwrap();
    assert!(config
        .read::<bool>("settings.json", "hyperEnabled", false)
        .unwrap());
    assert_eq!(
        config
            .read::<String>("shortcuts.json", "launcher", "".into())
            .unwrap(),
        "CommandOrControl+Space"
    );
    assert!(!result
        .categories
        .iter()
        .find(|c| c.name == "shortcuts.json")
        .unwrap()
        .error
        .is_empty());
    assert_eq!(
        std::fs::read(config.root.join("shortcuts.json")).unwrap(),
        b"broken"
    );
    std::fs::write(
        config.root.join("shortcuts.json"),
        br#"{"version":1,"launcher":"Super+Shift+Space"}"#,
    )
    .unwrap();
    let result = load(&config, &result).unwrap();
    assert!(result.categories.iter().all(|c| c.error.is_empty()));
    assert_eq!(
        config
            .read::<String>("shortcuts.json", "launcher", "".into())
            .unwrap(),
        "Super+Shift+Space"
    );
    std::fs::remove_dir_all(config.root).unwrap();
}
#[test]
fn custom_themes_are_cached_and_invalid_updates_keep_loaded_theme() {
    let config = setup();
    let path = config.root.join("themes/mine.json");
    let mut theme: Value =
        serde_json::from_str(include_str!("../../../src/lib/themes/graphite.json")).unwrap();
    theme["id"] = json!("mine");
    files::write(&path, &theme, None).unwrap();
    assert!(config
        .entries(&config.root.join("themes"))
        .unwrap()
        .is_empty());
    let result = load(&config, &report(&config)).unwrap();
    assert_eq!(config.json(&path).unwrap(), Some(theme.clone()));
    std::fs::write(&path, b"broken").unwrap();
    let result = load(&config, &result).unwrap();
    assert!(!result
        .categories
        .iter()
        .find(|c| c.name == "themes")
        .unwrap()
        .error
        .is_empty());
    assert_eq!(config.json(&path).unwrap(), Some(theme.clone()));
    let expected = config.bytes(&path).unwrap();
    assert!(config
        .write_file(&path, &theme, expected.as_deref())
        .is_err());
    std::fs::remove_dir_all(config.root).unwrap();
}
#[test]
fn malformed_settings_are_rejected_before_any_section_is_replaced() {
    let config = setup();
    let before = report(&config);
    std::fs::write(
        config.root.join("settings.json"),
        br#"{"version":1,"hyperEnabled":true,"interface":{"compactLauncher":"yes"}}"#,
    )
    .unwrap();
    let result = load(&config, &before).unwrap();
    assert!(!result.categories[0].error.is_empty());
    assert!(!config
        .read::<bool>("settings.json", "hyperEnabled", false)
        .unwrap());
    std::fs::remove_dir_all(config.root).unwrap();
}
#[cfg(unix)]
#[test]
fn broken_dotfile_links_report_errors_and_survive_reload() {
    let config = setup();
    let path = config.root.join("shortcuts.json");
    std::fs::remove_file(&path).unwrap();
    std::os::unix::fs::symlink(config.root.join("missing.json"), &path).unwrap();
    let result = load(&config, &report(&config)).unwrap();
    assert!(!result.categories[1].error.is_empty());
    assert!(std::fs::symlink_metadata(&path)
        .unwrap()
        .file_type()
        .is_symlink());
    std::fs::remove_dir_all(config.root).unwrap();
}
