use super::database::Database;
use rusqlite::params;
use serde::Serialize;

#[derive(Serialize)]
pub struct DeletionPlan {
    token: u64,
    count: usize,
}

#[derive(Default)]
pub struct DeletionPlans {
    revision: u64,
    pending: Option<(u64, Vec<String>)>,
}

impl DeletionPlans {
    pub fn prepare(
        &mut self,
        db: &Database,
        query: &str,
        kind: &str,
    ) -> Result<DeletionPlan, String> {
        db.refresh_unavailable(kind)?;
        let (condition, needle) = Database::search_condition(query);
        let mut statement = db
            .connection
            .prepare(&format!(
                "SELECT id FROM clips WHERE {condition} AND pinned=0"
            ))
            .map_err(|e| e.to_string())?;
        let ids = statement
            .query_map(params![needle, kind], |row| row.get::<_, String>(0))
            .map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| e.to_string())?;
        self.revision += 1;
        let plan = DeletionPlan {
            token: self.revision,
            count: ids.len(),
        };
        self.pending = Some((plan.token, ids));
        Ok(plan)
    }

    pub fn delete(&mut self, db: &Database, token: u64) -> Result<usize, String> {
        let (expected, ids) = self
            .pending
            .as_ref()
            .ok_or("Open Delete filtered results again to confirm the current matches.")?;
        if token != *expected {
            return Err("The deletion confirmation has changed. Please open it again.".into());
        }
        // Freeze the confirmed set across all pages. New arrivals are never
        // swept up, and items pinned since confirmation remain protected.
        let ids = serde_json::to_string(ids).map_err(|e| e.to_string())?;
        let deleted = db
            .connection
            .execute(
                "DELETE FROM clips WHERE pinned=0 AND id IN (SELECT value FROM json_each(?1))",
                [ids],
            )
            .map_err(|e| e.to_string())?;
        db.clean_images()?;
        self.pending = None;
        Ok(deleted)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clipboard::{
        drop_storage::{DropContent, PreparedDrop},
        model::{Capture, Settings},
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
                "tooki-bulk-delete-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            ));
            let db = Database::open(&root.join("history"), false).unwrap();
            Self { root, db }
        }
        fn record(&self, capture: Capture) -> String {
            self.db
                .record(
                    capture,
                    &Settings {
                        max_items: 1000,
                        ..Default::default()
                    },
                )
                .unwrap()
        }
        fn text(&self, text: &str) -> String {
            self.record(Capture {
                text: text.into(),
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
    fn unavailable_matches_live_paths_across_pages_and_filtered_deletion() {
        let f = Fixture::new();
        let existing = f.root.join("present.txt");
        fs::write(&existing, b"still here").unwrap();
        let folder = f.root.join("folder");
        fs::create_dir(&folder).unwrap();
        let available = f.record(Capture {
            files: vec![
                existing.to_string_lossy().into(),
                folder.to_string_lossy().into(),
            ],
            ..Default::default()
        });
        let text = f.text("missing text stays valid");
        f.text("https://example.com/missing");
        f.text("#ffffff");
        let mut ids = Vec::new();
        for i in 0..105 {
            ids.push(f.record(Capture {
                files: vec![f.root.join(format!("missing-{i}.txt")).to_string_lossy().into()],
                ..Default::default()
            }));
        }
        let image = f.root.join("source.png");
        fs::write(&image, b"saved image bytes").unwrap();
        let image_id = f.record(Capture {
            image: image.to_string_lossy().into(),
            ..Default::default()
        });
        let stored_image = f.db.get(&image_id).unwrap().image;
        assert_eq!(f.db.search("", "unavailable", 0, 100).unwrap().1, 105);
        fs::remove_file(&stored_image).unwrap();
        assert_eq!(f.db.search("", "unavailable", 100, 100).unwrap().0.len(), 6);
        assert_eq!(
            f.db.search("missing", "unavailable", 0, 100).unwrap().1,
            105
        );
        assert_eq!(f.db.locate("", "unavailable", &available).unwrap(), None);
        assert!(f.db.locate("", "unavailable", &image_id).unwrap().is_some());

        // Restored paths disappear on the next query, including stored images.
        fs::write(&stored_image, b"restored").unwrap();
        let restored = f.db.get(&ids[0]).unwrap().files[0].clone();
        fs::write(&restored, b"restored").unwrap();
        assert_eq!(f.db.search("", "unavailable", 0, 100).unwrap().1, 104);
        // A partially missing multi-file clip also qualifies.
        fs::remove_dir(&folder).unwrap();
        assert!(f
            .db
            .locate("", "unavailable", &available)
            .unwrap()
            .is_some());
        fs::create_dir(&folder).unwrap();
        let mut pinned = f.db.get(&ids[1]).unwrap();
        pinned.pinned = true;
        f.db.update(&pinned).unwrap();
        let mut plans = DeletionPlans::default();
        let plan = plans.prepare(&f.db, "", "unavailable").unwrap();
        assert_eq!(plan.count, 103);
        assert_eq!(plans.delete(&f.db, plan.token).unwrap(), 103);
        assert!(f.db.get(&pinned.id).is_ok());
        assert!(f.db.get(&text).is_ok());
        assert!(f.db.get(&available).is_ok());
        assert!(f.db.get(&image_id).is_ok());
        assert!(existing.exists() && folder.exists() && PathBuf::from(restored).exists());
    }

    #[test]
    fn deletes_five_mixed_matches_and_cleans_only_owned_data() {
        let f = Fixture::new();
        f.text("foo text");
        f.text("https://example.com/foo");
        let original = f.root.join("foo-file.txt");
        fs::write(&original, b"original").unwrap();
        let id = PreparedDrop::prepare(
            &f.db.root,
            DropContent {
                files: vec![original.to_string_lossy().into()],
                ..Default::default()
            },
        )
        .unwrap()
        .record(&f.db, &Settings::default())
        .unwrap();
        let owned = f.db.get(&id).unwrap().files[0].clone();
        let mut image_paths = Vec::new();
        for index in 0..2 {
            let image = f.root.join(format!("image-{index}.png"));
            fs::write(&image, format!("test image {index}")).unwrap();
            let id = f.record(Capture {
                image: image.to_string_lossy().into(),
                ..Default::default()
            });
            let mut clip = f.db.get(&id).unwrap();
            clip.ocr = "foo recognized text".into();
            f.db.update(&clip).unwrap();
            image_paths.push(clip.image);
        }
        let pinned = f.text("foo pinned");
        let mut clip = f.db.get(&pinned).unwrap();
        clip.pinned = true;
        f.db.update(&clip).unwrap();
        let other = f.text("unrelated");
        let mut plans = DeletionPlans::default();
        let plan = plans.prepare(&f.db, "foo", "all").unwrap();
        assert_eq!(plan.count, 5);
        assert_eq!(plans.delete(&f.db, plan.token).unwrap(), 5);
        assert!(f.db.get(&pinned).is_ok() && f.db.get(&other).is_ok());
        assert!(!PathBuf::from(owned).exists());
        assert!(image_paths.iter().all(|p| !PathBuf::from(p).exists()));
        assert_eq!(fs::read(original).unwrap(), b"original");
        assert_eq!(f.db.search("foo", "all", 0, 100).unwrap().1, 1);
    }

    #[test]
    fn snapshot_spans_pages_and_protects_new_arrivals_and_new_pins() {
        let f = Fixture::new();
        let ids: Vec<_> = (0..205).map(|i| f.text(&format!("foo {i}"))).collect();
        let mut plans = DeletionPlans::default();
        let plan = plans.prepare(&f.db, "foo", "text").unwrap();
        assert_eq!(plan.count, 205);
        let newer = f.text("foo new arrival");
        let mut pinned = f.db.get(&ids[0]).unwrap();
        pinned.pinned = true;
        f.db.update(&pinned).unwrap();
        assert_eq!(plans.delete(&f.db, plan.token).unwrap(), 204);
        assert!(f.db.get(&newer).is_ok() && f.db.get(&pinned.id).is_ok());
        assert!(plans.delete(&f.db, plan.token).is_err());
    }

    #[test]
    fn type_and_dropped_filters_empty_matches_and_stale_confirmations() {
        let f = Fixture::new();
        f.text("foo text");
        let link = f.text("https://example.com/foo");
        let dropped = f.record(Capture {
            text: "foo dropped".into(),
            dropped: true,
            ..Default::default()
        });
        let mut plans = DeletionPlans::default();
        assert_eq!(plans.prepare(&f.db, "absent", "all").unwrap().count, 0);
        assert_eq!(plans.prepare(&f.db, "", "pinned").unwrap().count, 0);
        let old = plans.prepare(&f.db, "foo", "all").unwrap();
        let plan = plans.prepare(&f.db, "fo", "link").unwrap();
        assert_eq!(plan.count, 1);
        assert!(plans.delete(&f.db, old.token).is_err());
        assert_eq!(plans.delete(&f.db, plan.token).unwrap(), 1);
        assert!(f.db.get(&link).is_err());
        let plan = plans.prepare(&f.db, "", "dropped").unwrap();
        assert_eq!(plan.count, 1);
        assert_eq!(plans.delete(&f.db, plan.token).unwrap(), 1);
        assert!(f.db.get(&dropped).is_err());
        assert_eq!(f.db.search("", "all", 0, 100).unwrap().1, 1);
    }
}
