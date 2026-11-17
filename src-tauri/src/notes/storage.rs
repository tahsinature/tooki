use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::path::Path;

pub type Result<T> = std::result::Result<T, String>;
#[derive(Clone, Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: String,
    pub title: String,
    pub document: Value,
    pub text: String,
    pub pinned: bool,
    pub deleted: bool,
    pub updated_at: i64,
    pub revision: i64,
}
pub struct Storage(pub Connection);
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
fn error(e: rusqlite::Error) -> String {
    e.to_string()
}
fn read(row: &rusqlite::Row) -> rusqlite::Result<Note> {
    let document: String = row.get(2)?;
    Ok(Note {
        id: row.get(0)?,
        title: row.get(1)?,
        document: serde_json::from_str(&document).map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(2, rusqlite::types::Type::Text, Box::new(e))
        })?,
        text: row.get(3)?,
        pinned: row.get(4)?,
        deleted: row.get(5)?,
        updated_at: row.get(6)?,
        revision: row.get(7)?,
    })
}
const COLUMNS: &str = "id,title,document,text,pinned,deleted,updated_at,revision";
impl Storage {
    pub fn open(path: &Path) -> Result<Self> {
        let db = Connection::open(path).map_err(error)?;
        db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
            CREATE TABLE IF NOT EXISTS notes(id TEXT PRIMARY KEY, title TEXT NOT NULL, document TEXT NOT NULL, text TEXT NOT NULL, pinned INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, revision INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX IF NOT EXISTS notes_order ON notes(deleted,pinned DESC,updated_at DESC);
            CREATE VIRTUAL TABLE IF NOT EXISTS note_search USING fts5(title,text,tokenize='trigram');
            CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN INSERT INTO note_search(rowid,title,text) VALUES(new.rowid,new.title,new.text); END;
            CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN DELETE FROM note_search WHERE rowid=old.rowid; INSERT INTO note_search(rowid,title,text) VALUES(new.rowid,new.title,new.text); END;
            CREATE TABLE IF NOT EXISTS note_state(key TEXT PRIMARY KEY,value TEXT NOT NULL);
            PRAGMA user_version=1;").map_err(error)?;
        Ok(Self(db))
    }
    pub fn get(&self, id: &str) -> Result<Note> {
        self.0
            .query_row(
                &format!("SELECT {COLUMNS} FROM notes WHERE id=?"),
                [id],
                read,
            )
            .map_err(error)
    }
    pub fn create(&self, title: &str, document: Value) -> Result<Note> {
        let title = title.trim().chars().take(200).collect::<String>();
        let text = plain_text(&document)?;
        let id: String = self
            .0
            .query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
            .map_err(error)?;
        self.0
            .execute(
                "INSERT INTO notes(id,title,document,text,updated_at) VALUES(?1,?2,?3,?4,?5)",
                params![id, title, document.to_string(), text, now()],
            )
            .map_err(error)?;
        self.get(&id)
    }
    pub fn save(&self, id: &str, revision: i64, title: &str, document: Value) -> Result<Note> {
        let text = plain_text(&document)?;
        let title = title.trim().chars().take(200).collect::<String>();
        let changed = self.0.execute("UPDATE notes SET title=?1,document=?2,text=?3,updated_at=?4,revision=revision+1 WHERE id=?5 AND revision=?6 AND deleted=0", params![title,document.to_string(),text,now(),id,revision]).map_err(error)?;
        if changed != 1 {
            return Err("This note changed or was moved to Trash. Your unsaved draft has been kept. Reopen Notes to recover it.".into());
        }
        self.get(id)
    }
    pub fn flag(&self, id: &str, flag: &str, value: bool) -> Result<Note> {
        if !matches!(flag, "pinned" | "deleted") {
            return Err("Unknown note property".into());
        }
        self.0
            .execute(
                &format!("UPDATE notes SET {flag}=?1,revision=revision+1 WHERE id=?2"),
                params![value, id],
            )
            .map_err(error)?;
        self.get(id)
    }
    pub fn search(&self, query: &str, deleted: bool) -> Result<Vec<Note>> {
        // Search metadata only: do not parse every note's rich-text document.
        // Title subsequences include the display fallback; body matching stays literal.
        let mut stmt = self.0.prepare("SELECT id,title,'null',text,pinned,deleted,updated_at,revision FROM notes WHERE deleted=?1 ORDER BY pinned DESC,updated_at DESC,id").map_err(error)?;
        let rows = stmt.query_map(params![deleted], read).map_err(error)?;
        let mut result = Vec::new();
        for row in rows {
            let mut note = row.map_err(error)?;
            if super::search::matches(&note.title, &note.text, query) {
                note.text = note.text.chars().take(160).collect();
                result.push(note);
            }
        }
        Ok(result)
    }
    pub fn state(&self, key: &str) -> Option<String> {
        self.0
            .query_row("SELECT value FROM note_state WHERE key=?", [key], |r| {
                r.get(0)
            })
            .ok()
    }
    pub fn set_state(&self, key: &str, value: &str) -> Result<()> {
        self.0.execute("INSERT INTO note_state(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", params![key,value]).map_err(error).map(|_| ())
    }
}
pub fn empty_document() -> Value {
    json!({"type":"doc","content":[{"type":"paragraph"}]})
}
pub fn plain_text(document: &Value) -> Result<String> {
    if document["type"] != "doc" || document.to_string().len() > 2_000_000 {
        return Err("Invalid note document, or note exceeds 2 MB.".into());
    }
    fn walk(node: &Value, depth: usize, output: &mut String) -> Result<()> {
        if depth > 64 {
            return Err("Note nesting is too deep.".into());
        }
        let kind = node["type"].as_str().ok_or("Invalid note node")?;
        if let Some(text) = node.get("text").and_then(Value::as_str) {
            output.push_str(text);
        }
        if let Some(children) = node.get("content") {
            for child in children.as_array().ok_or("Invalid note content")? {
                walk(child, depth + 1, output)?;
            }
        }
        if matches!(kind, "paragraph" | "heading" | "codeBlock" | "hardBreak") {
            output.push('\n');
        }
        Ok(())
    }
    let mut text = String::new();
    walk(document, 0, &mut text)?;
    Ok(text.trim_end().into())
}
