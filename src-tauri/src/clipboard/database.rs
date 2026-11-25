use super::model::*;
use rusqlite::{params, Connection};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

type Result<T> = std::result::Result<T, String>;
pub struct Database {
    pub connection: Connection,
    pub root: PathBuf,
}
impl Database {
    pub fn open(root: &Path, persist: bool) -> Result<Self> {
        std::fs::create_dir_all(root.join("images")).map_err(|e| e.to_string())?;
        let connection = if persist {
            Connection::open(root.join("history.sqlite3"))
        } else {
            Connection::open_in_memory()
        }
        .map_err(|e| e.to_string())?;
        connection.execute_batch("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
            CREATE TABLE IF NOT EXISTS clips(id TEXT PRIMARY KEY, fingerprint TEXT UNIQUE NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, source TEXT NOT NULL, copied_at INTEGER NOT NULL, pinned INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL);
            CREATE TEMP TABLE IF NOT EXISTS unavailable_clips(id TEXT PRIMARY KEY);
            CREATE INDEX IF NOT EXISTS clips_order ON clips(pinned DESC,copied_at DESC);
            CREATE INDEX IF NOT EXISTS clips_kind ON clips(kind,copied_at DESC);
            CREATE VIRTUAL TABLE IF NOT EXISTS search USING fts5(title,content,source,tokenize='trigram');
            CREATE TRIGGER IF NOT EXISTS clips_ai AFTER INSERT ON clips BEGIN INSERT INTO search(rowid,title,content,source) VALUES(new.rowid,new.title,new.content,new.source); END;
            CREATE TRIGGER IF NOT EXISTS clips_ad AFTER DELETE ON clips BEGIN DELETE FROM search WHERE rowid=old.rowid; END;
            CREATE TRIGGER IF NOT EXISTS clips_au AFTER UPDATE ON clips BEGIN DELETE FROM search WHERE rowid=old.rowid; INSERT INTO search(rowid,title,content,source) VALUES(new.rowid,new.title,new.content,new.source); END;
            PRAGMA user_version=1;").map_err(|e| e.to_string())?;
        // Older drops did not store provenance. Managed file paths identify
        // file drops; old text/image drops cannot be distinguished from copies.
        let managed_prefix = format!("{}/", root.join("files").to_string_lossy());
        connection.execute(
            "UPDATE clips SET payload=json_set(payload,'$.dropped',json(CASE WHEN EXISTS (
                SELECT 1 FROM json_each(clips.payload,'$.files')
                WHERE substr(value,1,length(?1))=?1
            ) THEN 'true' ELSE 'false' END)) WHERE json_type(payload,'$.dropped') IS NULL",
            [&managed_prefix],
        ).map_err(|e| e.to_string())?;
        Ok(Self {
            connection,
            root: root.into(),
        })
    }
    pub fn get(&self, id: &str) -> Result<Clip> {
        let value: String = self
            .connection
            .query_row("SELECT payload FROM clips WHERE id=?", [id], |r| r.get(0))
            .map_err(|_| "Clipboard item no longer exists".to_string())?;
        serde_json::from_str(&value).map_err(|e| e.to_string())
    }
    fn write(&self, clip: &Clip, fingerprint: &str) -> Result<()> {
        let payload = serde_json::to_string(clip).map_err(|e| e.to_string())?;
        self.connection.execute("INSERT INTO clips(id,fingerprint,kind,title,content,source,copied_at,pinned,payload) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9) ON CONFLICT(id) DO UPDATE SET title=excluded.title, content=excluded.content,source=excluded.source,copied_at=excluded.copied_at,pinned=excluded.pinned,payload=excluded.payload",
            params![clip.id,fingerprint,clip.kind,clip.title,format!("{}\n{}\n{}",clip.content,clip.ocr,clip.files.join("\n")),format!("{} {}",clip.source,clip.source_id),clip.copied_at,clip.pinned,payload]).map_err(|e|e.to_string())?;
        Ok(())
    }
    pub fn update(&self, clip: &Clip) -> Result<()> {
        let fingerprint: String = self
            .connection
            .query_row(
                "SELECT fingerprint FROM clips WHERE id=?",
                [&clip.id],
                |r| r.get(0),
            )
            .map_err(|e| e.to_string())?;
        self.write(clip, &fingerprint)
    }
    pub fn record(&self, mut capture: Capture, settings: &Settings) -> Result<String> {
        let kind = if !capture.files.is_empty() {
            "file"
        } else if !capture.image.is_empty() {
            "image"
        } else {
            classify(&capture.text)
        };
        let mut hash = Sha256::new();
        hash.update(kind);
        if kind == "image" {
            hash.update(std::fs::read(&capture.image).map_err(|e| e.to_string())?);
        } else {
            hash.update(&capture.text);
            hash.update(capture.files.join("\n"));
        }
        let fingerprint = hash
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        if kind == "image" {
            let target = self.root.join("images").join(format!("{fingerprint}.png"));
            if Path::new(&capture.image) != target {
                if target.exists() {
                    let _ = std::fs::remove_file(&capture.image);
                } else {
                    std::fs::rename(&capture.image, &target).map_err(|e| e.to_string())?;
                }
            }
            capture.image = target.to_string_lossy().into();
        }
        let previous = self
            .connection
            .query_row(
                "SELECT id FROM clips WHERE fingerprint=?",
                [&fingerprint],
                |r| r.get::<_, String>(0),
            )
            .ok()
            .and_then(|id| self.get(&id).ok());
        let time = now();
        let title = if kind == "image" {
            format!("Image ({} × {})", capture.width, capture.height)
        } else if kind == "file" {
            capture
                .files
                .iter()
                .map(|p| {
                    Path::new(p)
                        .file_name()
                        .unwrap_or_default()
                        .to_string_lossy()
                })
                .collect::<Vec<_>>()
                .join(", ")
        } else {
            capture
                .text
                .lines()
                .find(|l| !l.trim().is_empty())
                .unwrap_or("Text")
                .chars()
                .take(160)
                .collect()
        };
        let clip = Clip {
            // Deduplication must not remove a previously dropped item from
            // this collection when the same content is copied again.
            dropped: capture.dropped || previous.as_ref().is_some_and(|c| c.dropped),
            id: previous
                .as_ref()
                .map(|c| c.id.clone())
                .unwrap_or_else(|| fingerprint.clone()),
            kind: kind.into(),
            title,
            content: capture.text,
            files: capture.files,
            image: capture.image,
            width: capture.width,
            height: capture.height,
            bytes: capture.bytes,
            source: capture.source,
            source_id: capture.source_id,
            copied_at: time,
            first_copied_at: previous.as_ref().map(|c| c.first_copied_at).unwrap_or(time),
            copies: previous.as_ref().map(|c| c.copies + 1).unwrap_or(1),
            pinned: previous.as_ref().is_some_and(|c| c.pinned),
            ocr: previous.as_ref().map(|c| c.ocr.clone()).unwrap_or_default(),
            ocr_state: previous
                .as_ref()
                .map(|c| c.ocr_state.clone())
                .unwrap_or_else(|| {
                    if kind == "image" && settings.ocr_enabled {
                        "pending"
                    } else {
                        "none"
                    }
                    .into()
                }),
            html: capture.html,
            rtf: capture.rtf,
            missing_files: vec![],
        };
        self.write(&clip, &fingerprint)?;
        self.trim(settings)?;
        Ok(clip.id)
    }
    pub(super) fn search_condition(query: &str) -> (String, String) {
        let query = query.trim();
        let search_clause = if query.is_empty() {
            "1"
        } else if query.chars().count() >= 3 {
            "rowid IN (SELECT rowid FROM search WHERE search MATCH ?1)"
        } else {
            "(title LIKE ?1 ESCAPE '\\' OR content LIKE ?1 ESCAPE '\\' OR source LIKE ?1 ESCAPE '\\')"
        };
        let needle = if query.chars().count() >= 3 {
            format!("\"{}\"", query.replace('"', "\"\""))
        } else {
            format!(
                "%{}%",
                query
                    .replace('\\', "\\\\")
                    .replace('%', "\\%")
                    .replace('_', "\\_")
            )
        };
        let condition =
            format!("{search_clause} AND (?2='all' OR (?2='pinned' AND pinned=1) OR (?2='dropped' AND json_extract(payload,'$.dropped')=1) OR (?2='unavailable' AND id IN (SELECT id FROM unavailable_clips)) OR kind=?2)");
        // ?1 remains bound even for empty queries.
        let condition = format!("(?1 IS NOT NULL) AND {condition}");
        (condition, needle)
    }
    pub fn locate(&self, query: &str, kind: &str, id: &str) -> Result<Option<usize>> {
        use rusqlite::OptionalExtension;
        self.refresh_unavailable(kind)?;
        let (condition, needle) = Self::search_condition(query);
        self.connection.query_row(&format!("SELECT position FROM (SELECT id,row_number() OVER (ORDER BY pinned DESC,copied_at DESC,id)-1 AS position FROM clips WHERE {condition}) WHERE id=?3"),params![needle,kind,id],|r|r.get::<_,i64>(0)).optional().map(|v|v.map(|n|n as usize)).map_err(|e|e.to_string())
    }
    pub fn search(
        &self,
        query: &str,
        kind: &str,
        offset: usize,
        limit: usize,
    ) -> Result<(Vec<Clip>, usize)> {
        self.refresh_unavailable(kind)?;
        let (condition, needle) = Self::search_condition(query);
        let total = self
            .connection
            .query_row(
                &format!("SELECT count(*) FROM clips WHERE {condition}"),
                params![needle, kind],
                |r| r.get::<_, i64>(0),
            )
            .map_err(|e| e.to_string())?;
        let mut stmt=self.connection.prepare(&format!("SELECT payload FROM clips WHERE {condition} ORDER BY pinned DESC,copied_at DESC,id LIMIT ?3 OFFSET ?4")).map_err(|e|e.to_string())?;
        let rows = stmt
            .query_map(
                params![needle, kind, limit.min(500) as i64, offset as i64],
                |r| r.get::<_, String>(0),
            )
            .map_err(|e| e.to_string())?;
        let mut items = vec![];
        for row in rows {
            let mut item: Clip = serde_json::from_str(&row.map_err(|e| e.to_string())?)
                .map_err(|e| e.to_string())?;
            item.missing_files = item
                .files
                .iter()
                .filter(|p| !Path::new(p).exists())
                .cloned()
                .collect();
            item.html.clear();
            item.rtf.clear();
            items.push(item);
        }
        Ok((items, total as usize))
    }
    pub fn remove(&self, id: &str) -> Result<()> {
        self.connection
            .execute("DELETE FROM clips WHERE id=?", [id])
            .map_err(|e| e.to_string())?;
        self.clean_images()
    }
    pub fn clear(&self, include_pinned: bool) -> Result<()> {
        self.connection
            .execute("DELETE FROM clips WHERE ? OR pinned=0", [include_pinned])
            .map_err(|e| e.to_string())?;
        self.clean_images()
    }
    pub fn trim(&self, s: &Settings) -> Result<()> {
        if s.retention_days > 0 {
            self.connection
                .execute(
                    "DELETE FROM clips WHERE pinned=0 AND copied_at<?",
                    [now() - i64::from(s.retention_days) * 86400000],
                )
                .map_err(|e| e.to_string())?;
        }
        self.connection.execute("DELETE FROM clips WHERE id IN(SELECT id FROM clips WHERE pinned=0 AND kind='image' ORDER BY copied_at DESC LIMIT -1 OFFSET ?)",[s.max_images as i64]).map_err(|e|e.to_string())?;
        self.connection.execute("DELETE FROM clips WHERE id IN(SELECT id FROM clips WHERE pinned=0 ORDER BY copied_at DESC LIMIT -1 OFFSET ?)",[s.max_items as i64]).map_err(|e|e.to_string())?;
        self.clean_images()
    }
    pub fn clean_images(&self) -> Result<()> {
        if let Ok(entries) = std::fs::read_dir(self.root.join("exports")) {
            for entry in entries.flatten() {
                let path = entry.path();
                if let Some(id) = path.file_stem().and_then(|s| s.to_str()) {
                    if self.get(id).is_err() {
                        let _ = std::fs::remove_file(path);
                    }
                }
            }
        }

        let mut stmt = self
            .connection
            .prepare("SELECT json_extract(payload,'$.image') FROM clips WHERE kind='image'")
            .map_err(|e| e.to_string())?;
        let keep = stmt
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(|e| e.to_string())?
            .collect::<std::result::Result<std::collections::HashSet<_>, _>>()
            .map_err(|e| e.to_string())?;
        if let Ok(entries) = std::fs::read_dir(self.root.join("images")) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_file() && !keep.contains(path.to_string_lossy().as_ref()) {
                    let _ = std::fs::remove_file(path);
                }
            }
        }
        super::drop_storage::clean_files(self)
    }
    pub fn set_persistence(&mut self, persist: bool) -> Result<()> {
        let mut next = Self::open(&self.root, persist)?;
        {
            let backup = rusqlite::backup::Backup::new(&self.connection, &mut next.connection)
                .map_err(|e| e.to_string())?;
            backup
                .run_to_completion(100, std::time::Duration::from_millis(5), None)
                .map_err(|e| e.to_string())?;
        }
        self.connection = next.connection;
        if !persist {
            for name in [
                "history.sqlite3",
                "history.sqlite3-wal",
                "history.sqlite3-shm",
            ] {
                let path = self.root.join(name);
                if path.exists() {
                    std::fs::remove_file(path).map_err(|e| e.to_string())?;
                }
            }
        }
        Ok(())
    }
}
