use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Capture {
    pub dropped: bool,
    pub text: String,
    pub files: Vec<String>,
    pub image: String,
    pub width: u32,
    pub height: u32,
    pub bytes: u64,
    pub source: String,
    pub source_id: String,
    pub html: String,
    pub rtf: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Clip {
    #[serde(default)]
    pub dropped: bool,
    pub id: String,
    pub kind: String,
    pub title: String,
    pub content: String,
    pub files: Vec<String>,
    pub image: String,
    pub width: u32,
    pub height: u32,
    pub bytes: u64,
    pub source: String,
    pub source_id: String,
    pub copied_at: i64,
    pub first_copied_at: i64,
    pub copies: u32,
    pub pinned: bool,
    pub ocr: String,
    pub ocr_state: String,
    pub html: String,
    pub rtf: String,
    pub missing_files: Vec<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub enabled: bool,
    pub persist_history: bool,
    pub max_items: usize,
    pub max_images: usize,
    pub retention_days: u32,
    pub ocr_enabled: bool,
    pub ignored_apps: Vec<String>,
}
impl Default for Settings {
    fn default() -> Self {
        Self {
            enabled: true,
            persist_history: true,
            max_items: 200,
            max_images: 50,
            retention_days: 0,
            ocr_enabled: true,
            ignored_apps: vec![
                "com.1password.1password".into(),
                "com.agilebits.onepassword7".into(),
                "com.bitwarden.desktop".into(),
                "com.apple.keychainaccess".into(),
            ],
        }
    }
}
impl Settings {
    pub fn validate(&self) -> Result<(), String> {
        if !(1..=100_000).contains(&self.max_items)
            || self.max_images > 10_000
            || self.retention_days > 3650
        {
            return Err("Invalid history limit".into());
        }
        if self.ignored_apps.len() > 500
            || self
                .ignored_apps
                .iter()
                .any(|s| s.len() > 255 || s.contains('\n'))
        {
            return Err("Invalid excluded application list".into());
        }
        Ok(())
    }
}
pub fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
pub fn classify(text: &str) -> &'static str {
    let t = text.trim();
    if t.starts_with('#')
        && [4, 7, 9].contains(&t.len())
        && t[1..].bytes().all(|c| c.is_ascii_hexdigit())
    {
        "color"
    } else if !t.chars().any(char::is_whitespace)
        && (t.starts_with("https://")
            || t.starts_with("http://")
            || t.starts_with("mailto:")
            || t.starts_with("tel:"))
    {
        "link"
    } else {
        "text"
    }
}
