use super::{database::Database, model::Clip};
use std::path::Path;

fn missing(path: &str) -> bool {
    // Permission and other I/O failures are not evidence that data is gone.
    path.is_empty() || matches!(Path::new(path).try_exists(), Ok(false))
}

impl Database {
    pub(super) fn refresh_unavailable(&self, filter: &str) -> Result<(), String> {
        if filter != "unavailable" {
            return Ok(());
        }
        let mut statement = self
            .connection
            .prepare("SELECT payload FROM clips WHERE kind IN ('file','image')")
            .map_err(|e| e.to_string())?;
        let rows = statement
            .query_map([], |row| row.get::<_, String>(0))
            .map_err(|e| e.to_string())?;
        let mut ids = Vec::new();
        for row in rows {
            let clip: Clip = serde_json::from_str(&row.map_err(|e| e.to_string())?)
                .map_err(|e| e.to_string())?;
            let unavailable = match clip.kind.as_str() {
                "image" => missing(&clip.image),
                "file" => clip.files.is_empty() || clip.files.iter().any(|path| missing(path)),
                _ => false,
            };
            if unavailable {
                ids.push(clip.id);
            }
        }
        // One fresh snapshot supplies counts, paging, locating and deletion
        // preparation. It is temporary and never persists availability claims.
        let ids = serde_json::to_string(&ids).map_err(|e| e.to_string())?;
        self.connection
            .execute("DELETE FROM unavailable_clips", [])
            .map_err(|e| e.to_string())?;
        self.connection
            .execute(
                "INSERT INTO unavailable_clips SELECT value FROM json_each(?1)",
                [ids],
            )
            .map_err(|e| e.to_string())?;
        Ok(())
    }
}
