use super::{
    database::Database,
    drop_storage::{DropContent, PreparedDrop},
    model::Settings,
};
use std::{fs, path::PathBuf};

struct Fixture {
    root: PathBuf,
    db: Database,
}
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
        let root = std::env::temp_dir().join(format!(
            "tooki-drop-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        fs::create_dir_all(&root).unwrap();
        let db = Database::open(&root.join("history"), false).unwrap();
        Self { root, db }
    }
    fn record(&self, content: DropContent) -> String {
        PreparedDrop::prepare(&self.db.root, content)
            .unwrap()
            .record(&self.db, &Settings::default())
            .unwrap()
    }
    fn files(&self, files: Vec<PathBuf>) -> String {
        self.record(DropContent {
            files: files
                .iter()
                .map(|p| p.to_string_lossy().into_owned())
                .collect(),
            ..Default::default()
        })
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}

#[test]
fn dropped_filter_keeps_content_types_search_paging_and_deduplication() {
    let f = Fixture::new();
    let text = f.record(DropContent {
        text: "dropped note".into(),
        ..Default::default()
    });
    let link = f.record(DropContent {
        url: "https://example.com/drop".into(),
        ..Default::default()
    });
    let file = f.root.join("photo.jpg");
    fs::write(&file, b"original bytes").unwrap();
    let file_id = f.files(vec![file]);
    let ordinary =
        f.db.record(
            super::model::Capture {
                text: "copied note".into(),
                ..Default::default()
            },
            &Settings::default(),
        )
        .unwrap();
    assert!(!f.db.get(&ordinary).unwrap().dropped);
    let (items, total) = f.db.search("", "dropped", 0, 100).unwrap();
    assert_eq!(total, 3);
    assert!(items.iter().all(|c| c.dropped));
    assert_eq!(f.db.get(&text).unwrap().kind, "text");
    assert_eq!(f.db.get(&link).unwrap().kind, "link");
    assert_eq!(f.db.get(&file_id).unwrap().kind, "file");
    assert_eq!(f.db.search("note", "dropped", 0, 100).unwrap().1, 1);
    assert_eq!(f.db.search("no", "dropped", 0, 100).unwrap().1, 1);
    assert_eq!(f.db.search("", "dropped", 1, 1).unwrap().0.len(), 1);
    assert!(f.db.locate("", "dropped", &text).unwrap().is_some());
    assert_eq!(f.db.locate("", "dropped", &ordinary).unwrap(), None);
    let copied_again =
        f.db.record(
            super::model::Capture {
                text: "dropped note".into(),
                ..Default::default()
            },
            &Settings::default(),
        )
        .unwrap();
    assert_eq!(copied_again, text);
    assert!(f.db.get(&text).unwrap().dropped);
    assert_eq!(f.db.search("", "dropped", 0, 100).unwrap().1, 3);
    let dropped_later = f.record(DropContent {
        text: "copied note".into(),
        ..Default::default()
    });
    assert_eq!(dropped_later, ordinary);
    assert!(f.db.get(&ordinary).unwrap().dropped);
}

#[test]
fn old_managed_file_drops_are_migrated_without_marking_other_files() {
    let f = Fixture::new();
    let root = f.root.join("persistent");
    let db = Database::open(&root, true).unwrap();
    let managed = root.join("files/drop-old/0/photo.jpg");
    fs::create_dir_all(managed.parent().unwrap()).unwrap();
    fs::write(&managed, b"original").unwrap();
    let old_drop = db
        .record(
            super::model::Capture {
                files: vec![managed.to_string_lossy().into()],
                ..Default::default()
            },
            &Settings::default(),
        )
        .unwrap();
    let regular = db
        .record(
            super::model::Capture {
                files: vec![root
                    .join("files-neighbor/photo.jpg")
                    .to_string_lossy()
                    .into()],
                ..Default::default()
            },
            &Settings::default(),
        )
        .unwrap();
    db.connection
        .execute(
            "UPDATE clips SET payload=json_remove(payload,'$.dropped')",
            [],
        )
        .unwrap();
    drop(db);
    let restored = Database::open(&root, true).unwrap();
    assert!(restored.get(&old_drop).unwrap().dropped);
    assert!(!restored.get(&regular).unwrap().dropped);
    assert_eq!(restored.search("photo", "dropped", 0, 100).unwrap().1, 1);
    assert_eq!(restored.search("", "file", 0, 100).unwrap().1, 2);
    assert_eq!(fs::read(managed).unwrap(), b"original");
}

#[test]
fn dropped_files_preserve_bytes_names_and_survive_original_removal() {
    let f = Fixture::new();
    let source = f.root.join("photo.jpg");
    let bytes = vec![42; 1_100_000];
    fs::write(&source, &bytes).unwrap();
    let id = f.files(vec![source.clone()]);
    let clip = f.db.get(&id).unwrap();
    assert_eq!(clip.title, "photo.jpg");
    assert_eq!(clip.bytes, bytes.len() as u64);
    fs::remove_file(source).unwrap();
    assert_eq!(fs::read(&clip.files[0]).unwrap(), bytes);
    f.db.remove(&id).unwrap();
    assert!(!PathBuf::from(&clip.files[0]).exists());
}

#[test]
fn multiple_files_with_same_name_and_nested_folders_are_preserved() {
    let f = Fixture::new();
    let folder = f.root.join("folder");
    fs::create_dir_all(folder.join("nested")).unwrap();
    fs::write(folder.join("nested/data.bin"), b"nested").unwrap();
    fs::write(folder.join("same.txt"), b"one").unwrap();
    fs::write(f.root.join("same.txt"), b"two").unwrap();
    let id = f.files(vec![
        folder.join("same.txt"),
        f.root.join("same.txt"),
        folder.clone(),
    ]);
    let clip = f.db.get(&id).unwrap();
    assert_eq!(fs::read(&clip.files[0]).unwrap(), b"one");
    assert_eq!(fs::read(&clip.files[1]).unwrap(), b"two");
    assert_eq!(
        fs::read(PathBuf::from(&clip.files[2]).join("nested/data.bin")).unwrap(),
        b"nested"
    );
    f.db.clear(true).unwrap();
    assert!(folder.join("same.txt").exists());
    assert!(clip.files.iter().all(|p| !PathBuf::from(p).exists()));
}

#[test]
fn failed_drop_cleans_partial_copies_and_rejects_recursive_import() {
    let f = Fixture::new();
    let source = f.root.join("valid.txt");
    fs::write(&source, b"original").unwrap();
    let content = DropContent {
        files: vec![
            source.to_string_lossy().into(),
            f.root.join("missing").to_string_lossy().into(),
        ],
        ..Default::default()
    };
    assert!(PreparedDrop::prepare(&f.db.root, content).is_err());
    assert_eq!(fs::read_dir(f.db.root.join("staging")).unwrap().count(), 0);
    assert!(PreparedDrop::prepare(
        &f.db.root,
        DropContent {
            files: vec![f.root.to_string_lossy().into()],
            ..Default::default()
        }
    )
    .is_err());
    assert_eq!(fs::read(source).unwrap(), b"original");
}

#[test]
fn text_and_links_use_existing_history_classification() {
    let f = Fixture::new();
    let text = f.record(DropContent {
        text: "Dropped ✓ text".into(),
        ..Default::default()
    });
    assert_eq!(f.db.get(&text).unwrap().content, "Dropped ✓ text");
    let link = f.record(DropContent {
        url: "https://example.com/photo.jpg".into(),
        text: "caption".into(),
        ..Default::default()
    });
    assert_eq!(f.db.get(&link).unwrap().kind, "link");
    assert_eq!(
        f.db.get(&link).unwrap().content,
        "https://example.com/photo.jpg"
    );
    assert!(PreparedDrop::prepare(&f.db.root, DropContent::default()).is_err());
}

#[test]
fn png_drop_preserves_bytes_dimensions_and_image_limit() {
    use base64::Engine;
    let f = Fixture::new();
    let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=";
    let content = || DropContent {
        png: png.into(),
        width: 1,
        height: 1,
        ..Default::default()
    };
    let id = f.record(content());
    let clip = f.db.get(&id).unwrap();
    assert_eq!(clip.kind, "image");
    assert_eq!((clip.width, clip.height), (1, 1));
    assert_eq!(
        fs::read(&clip.image).unwrap(),
        base64::engine::general_purpose::STANDARD
            .decode(png)
            .unwrap()
    );
    let settings = Settings {
        max_images: 0,
        ..Default::default()
    };
    assert!(PreparedDrop::prepare(&f.db.root, content())
        .unwrap()
        .record(&f.db, &settings)
        .is_err());
}

#[test]
fn cleanup_preserves_pinned_and_other_references_to_managed_files() {
    let f = Fixture::new();
    let source = f.root.join("original.txt");
    fs::write(&source, b"saved").unwrap();
    let id = f.files(vec![source.clone()]);
    let mut clip = f.db.get(&id).unwrap();
    clip.pinned = true;
    f.db.update(&clip).unwrap();
    f.db.clear(false).unwrap();
    assert!(PathBuf::from(&clip.files[0]).exists());
    // A separate copied-file history item can also reference a managed file.
    let other =
        f.db.record(
            super::model::Capture {
                files: clip.files.clone(),
                text: "reference".into(),
                ..Default::default()
            },
            &Settings::default(),
        )
        .unwrap();
    f.db.remove(&id).unwrap();
    assert!(PathBuf::from(&clip.files[0]).exists());
    f.db.remove(&other).unwrap();
    assert!(!PathBuf::from(&clip.files[0]).exists());
    assert!(source.exists());
}
