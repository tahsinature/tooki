use super::{database::Database, model::*};
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
static NEXT: AtomicUsize = AtomicUsize::new(0);
struct Fixture {
    db: Database,
    root: PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "tooki-clipboard-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        let db = Database::open(&root, false).unwrap();
        Self { db, root }
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
    }
}
fn capture(text: &str) -> Capture {
    Capture {
        text: text.into(),
        source: "Test Notes".into(),
        ..Default::default()
    }
}

#[test]
fn requested_recognition_caches_text_even_when_automatic_recognition_is_off() {
    let f = Fixture::new();
    let settings = Settings {
        ocr_enabled: false,
        ..Settings::default()
    };
    let db = std::sync::Mutex::new(Database::open(&f.root.join("ocr"), false).unwrap());
    let id = db
        .lock()
        .unwrap()
        .record(capture("image fixture"), &settings)
        .unwrap();
    let mut clip = db.lock().unwrap().get(&id).unwrap();
    clip.kind = "image".into();
    clip.image = "test.png".into();
    db.lock().unwrap().update(&clip).unwrap();
    // Use an isolated database fixture rather than native Vision in this test.
    let text =
        super::ocr::recognize(&db, &id, false, |_| Ok("First line\nSecond line".into())).unwrap();
    assert_eq!(text, "First line\nSecond line");
    assert_eq!(
        super::ocr::recognize(&db, &id, false, |_| panic!(
            "cached result must not run OCR"
        ))
        .unwrap(),
        text
    );
    assert_eq!(db.lock().unwrap().get(&id).unwrap().image, "test.png");
    // A retry can legitimately find no text, and must replace the old result.
    assert_eq!(
        super::ocr::recognize(&db, &id, true, |_| Ok(String::new())).unwrap(),
        ""
    );
    assert_eq!(db.lock().unwrap().get(&id).unwrap().ocr_state, "done");
    assert!(super::ocr::recognize(&db, &id, true, |_| Err("Unreadable image".into())).is_err());
    assert_eq!(db.lock().unwrap().get(&id).unwrap().ocr_state, "failed");
    super::ocr::recognize(&db, &id, false, |_| {
        let database = db.lock().unwrap();
        let mut current = database.get(&id).unwrap();
        current.pinned = true;
        database.update(&current).unwrap();
        Ok("Recovered text".into())
    })
    .unwrap();
    assert!(db.lock().unwrap().get(&id).unwrap().pinned);
    assert!(super::ocr::recognize(&db, &id, true, |_| {
        db.lock().unwrap().remove(&id).unwrap();
        Ok("Deleted while recognizing".into())
    })
    .is_err());
    assert!(db.lock().unwrap().get(&id).is_err());
}
#[test]
fn file_actions_require_existing_files_and_never_export_text() {
    let f = Fixture::new();
    let id =
        f.db.record(capture("plain text"), &Settings::default())
            .unwrap();
    let mut clip = f.db.get(&id).unwrap();
    assert!(super::commands::file_paths(&clip).is_err());
    let image = f.root.join("saved image.png");
    std::fs::write(&image, b"test image").unwrap();
    clip.image = image.to_string_lossy().into_owned();
    assert_eq!(
        super::commands::file_paths(&clip).unwrap(),
        vec![clip.image.clone()]
    );
    let original = f.root.join("original.txt");
    std::fs::write(&original, b"test file").unwrap();
    clip.files = vec![original.to_string_lossy().into_owned(), clip.image.clone()];
    assert_eq!(super::commands::file_paths(&clip).unwrap(), clip.files);
    std::fs::remove_file(&original).unwrap();
    assert!(super::commands::file_paths(&clip).is_err());
    clip.files.clear();
    std::fs::remove_file(&image).unwrap();
    assert!(super::commands::file_paths(&clip).is_err());
    assert!(!f.root.join("exports").exists());
}
#[test]
fn deduplication_preserves_pin_and_first_copy() {
    let f = Fixture::new();
    let s = Settings::default();
    let id = f.db.record(capture("hello world"), &s).unwrap();
    let mut clip = f.db.get(&id).unwrap();
    clip.pinned = true;
    f.db.update(&clip).unwrap();
    assert_eq!(id, f.db.record(capture("hello world"), &s).unwrap());
    let next = f.db.get(&id).unwrap();
    assert!(next.pinned);
    assert_eq!(next.copies, 2);
    assert_eq!(next.first_copied_at, clip.first_copied_at);
    assert_eq!(f.db.search("", "all", 0, 100).unwrap().1, 1);
}
#[test]
fn search_is_literal_and_indexes_source_and_ocr() {
    let f = Fixture::new();
    let s = Settings::default();
    let id =
        f.db.record(capture("C++ says \"hello\" 100%_done"), &s)
            .unwrap();
    let mut clip = f.db.get(&id).unwrap();
    clip.ocr = "receipt total ninety".into();
    f.db.update(&clip).unwrap();
    for query in [
        "C++",
        "\"hello\"",
        "100%",
        "%_",
        "Test Notes",
        "receipt",
        "++",
    ] {
        assert_eq!(f.db.search(query, "all", 0, 100).unwrap().1, 1, "{query}");
    }
    assert_eq!(f.db.search("missing", "all", 0, 100).unwrap().1, 0);
    assert_eq!(f.db.search("", "image", 0, 100).unwrap().1, 0);
}
#[test]
fn pinned_items_survive_limits_and_clear() {
    let f = Fixture::new();
    let mut s = Settings::default();
    let id = f.db.record(capture("keep me"), &s).unwrap();
    let mut clip = f.db.get(&id).unwrap();
    clip.pinned = true;
    f.db.update(&clip).unwrap();
    s.max_items = 1;
    f.db.record(capture("one"), &s).unwrap();
    f.db.record(capture("two"), &s).unwrap();
    assert_eq!(f.db.search("", "all", 0, 100).unwrap().1, 2);
    f.db.clear(false).unwrap();
    assert!(f.db.get(&id).is_ok());
    f.db.clear(true).unwrap();
    assert_eq!(f.db.search("", "all", 0, 100).unwrap().1, 0);
}
#[test]
fn image_cleanup_and_persistence_roundtrip() {
    let mut f = Fixture::new();
    let s = Settings::default();
    let staged = f.root.join("sample.png");
    std::fs::write(&staged, b"synthetic image bytes").unwrap();
    let id =
        f.db.record(
            Capture {
                image: staged.to_string_lossy().into(),
                ..Default::default()
            },
            &s,
        )
        .unwrap();
    let path = f.db.get(&id).unwrap().image;
    f.db.set_persistence(true).unwrap();
    let persisted = Database::open(&f.root, true).unwrap();
    assert!(persisted.get(&id).is_ok());
    drop(persisted);
    f.db.set_persistence(false).unwrap();
    assert!(!f.root.join("history.sqlite3").exists());
    assert!(f.db.get(&id).is_ok());
    f.db.remove(&id).unwrap();
    assert!(!std::path::Path::new(&path).exists());
}
#[test]
fn large_history_paging_reaches_last_item() {
    let f = Fixture::new();
    let s = Settings {
        max_items: 6000,
        ..Default::default()
    };
    for i in 0..5000 {
        f.db.record(capture(&format!("sample {i:04}")), &s).unwrap();
    }
    let (last, count) = f.db.search("", "all", 4900, 100).unwrap();
    assert_eq!(count, 5000);
    assert_eq!(last.len(), 100);
    let start = std::time::Instant::now();
    assert_eq!(f.db.search("sample 4999", "all", 0, 100).unwrap().1, 1);
    eprintln!("5,000-item indexed search: {:?}", start.elapsed());
}

#[test]
fn restored_selection_tracks_identity_after_new_copies() {
    let f = Fixture::new();
    let s = Settings::default();
    let id = f.db.record(capture("remember this"), &s).unwrap();
    let mut clip = f.db.get(&id).unwrap();
    clip.copied_at = 1;
    f.db.update(&clip).unwrap();
    f.db.record(capture("newer"), &s).unwrap();
    assert_eq!(f.db.locate("", "all", &id).unwrap(), Some(1));
    assert_eq!(f.db.locate("remember", "all", &id).unwrap(), Some(0));
    assert_eq!(f.db.locate("newer", "all", &id).unwrap(), None);
    f.db.remove(&id).unwrap();
    assert_eq!(f.db.locate("", "all", &id).unwrap(), None);
}
