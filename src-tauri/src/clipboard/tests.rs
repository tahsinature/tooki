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
