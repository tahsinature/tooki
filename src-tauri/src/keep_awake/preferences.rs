use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Preferences {
    pub show_menu_bar_icon: bool,
    pub mode: super::model::Mode,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            show_menu_bar_icon: true,
            mode: super::model::Mode::System,
        }
    }
}
pub fn load(app: &tauri::AppHandle) -> Result<Preferences, String> {
    let config = crate::config::get(app);
    config.migrate(
        "settings.json",
        "keepAwake",
        config.legacy_json::<Preferences>("keep-awake.json")?,
        Preferences::default(),
    )?;
    crate::config::read(app, "keepAwake")
}
pub fn save(app: &tauri::AppHandle, preferences: &Preferences) -> Result<(), String> {
    crate::config::save(app, "keepAwake", preferences)
}
