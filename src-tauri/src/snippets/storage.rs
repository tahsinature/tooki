use super::model::*;
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;

pub struct Storage(Connection);
impl Storage {
    pub fn open(path: &Path) -> Result<Self, String> {
        let db = Connection::open(path).map_err(|e| e.to_string())?;
        db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=3000;
            CREATE TABLE IF NOT EXISTS definitions(id TEXT PRIMARY KEY, body TEXT NOT NULL, revision INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS configurations(id TEXT PRIMARY KEY, body TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS preferences(key TEXT PRIMARY KEY, body TEXT NOT NULL);").map_err(|e| e.to_string())?;
        Ok(Self(db))
    }
    pub fn list(&self) -> Result<Vec<Record>, String> {
        let mut query = self.0.prepare("SELECT d.body,c.body,d.revision FROM definitions d JOIN configurations c ON c.id=d.id ORDER BY d.rowid").map_err(|e| e.to_string())?;
        let rows = query
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            })
            .map_err(|e| e.to_string())?
            .map(|result| {
                let (definition, configuration, revision) = result.map_err(|e| e.to_string())?;
                Ok(Record {
                    definition: serde_json::from_str(&definition)
                        .map_err(|e| format!("Cannot read snippet definition: {e}"))?,
                    configuration: serde_json::from_str(&configuration)
                        .map_err(|e| format!("Cannot read personal snippet settings: {e}"))?,
                    revision,
                })
            })
            .collect();
        rows
    }
    pub fn save(&mut self, mut record: Record) -> Result<Record, String> {
        record.validate()?;
        let mut all = self.list()?;
        all.retain(|item| item.definition.id != record.definition.id);
        if all.len() >= 1000 {
            return Err("This version supports up to 1,000 snippets.".into());
        }
        all.push(record.clone());
        validate_conflicts(&all)?;
        let transaction = self.0.transaction().map_err(|e| e.to_string())?;
        let revision: Option<i64> = transaction
            .query_row(
                "SELECT revision FROM definitions WHERE id=?",
                [&record.definition.id],
                |row| row.get(0),
            )
            .optional()
            .map_err(|e| e.to_string())?;
        if revision.unwrap_or(0) != record.revision {
            return Err("This snippet changed in another window. Reopen it before saving.".into());
        }
        record.revision += 1;
        transaction.execute("INSERT INTO definitions VALUES(?1,?2,?3) ON CONFLICT(id) DO UPDATE SET body=excluded.body, revision=excluded.revision", params![record.definition.id, serde_json::to_string(&record.definition).map_err(|e| e.to_string())?, record.revision]).map_err(|e| e.to_string())?;
        transaction.execute("INSERT INTO configurations VALUES(?1,?2) ON CONFLICT(id) DO UPDATE SET body=excluded.body", params![record.definition.id, serde_json::to_string(&record.configuration).map_err(|e| e.to_string())?]).map_err(|e| e.to_string())?;
        transaction.commit().map_err(|e| e.to_string())?;
        Ok(record)
    }
    pub fn delete(&mut self, id: &str, revision: i64) -> Result<(), String> {
        let transaction = self.0.transaction().map_err(|e| e.to_string())?;
        let deleted = transaction
            .execute(
                "DELETE FROM definitions WHERE id=? AND revision=?",
                params![id, revision],
            )
            .map_err(|e| e.to_string())?;
        if deleted != 1 {
            return Err("This snippet changed. Reopen it before deleting.".into());
        }
        transaction
            .execute("DELETE FROM configurations WHERE id=?", [id])
            .map_err(|e| e.to_string())?;
        transaction.commit().map_err(|e| e.to_string())
    }
    pub fn preferences(&self) -> Result<Preferences, String> {
        let body: Option<String> = self
            .0
            .query_row(
                "SELECT body FROM preferences WHERE key='general'",
                [],
                |row| row.get(0),
            )
            .optional()
            .map_err(|e| e.to_string())?;
        body.map(|body| serde_json::from_str(&body).map_err(|e| e.to_string()))
            .unwrap_or_else(|| Ok(Preferences::default()))
    }
    pub fn set_preferences(&self, value: &Preferences) -> Result<(), String> {
        if value.excluded_apps.len() > 200
            || value
                .excluded_apps
                .iter()
                .any(|id| id.len() > 200 || id.contains(char::is_whitespace))
        {
            return Err("Enter valid application bundle identifiers, one per line.".into());
        }
        self.0.execute("INSERT INTO preferences VALUES('general',?) ON CONFLICT(key) DO UPDATE SET body=excluded.body", [serde_json::to_string(value).map_err(|e| e.to_string())?]).map_err(|e| e.to_string())?;
        Ok(())
    }
}
