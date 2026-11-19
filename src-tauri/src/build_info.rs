use serde::Serialize;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildInfo {
    name: String,
    version: String,
    built_at: u64,
    build_number: &'static str,
    development: bool,
    install_unavailable: Option<String>,
}

#[tauri::command]
pub fn build_info(app: tauri::AppHandle) -> BuildInfo {
    BuildInfo {
        name: app.package_info().name.clone(),
        version: app.package_info().version.to_string(),
        built_at: env!("TOOKI_BUILD_TIMESTAMP").parse().unwrap_or_default(),
        build_number: env!("TOOKI_BUILD_NUMBER"),
        development: cfg!(debug_assertions) || app.config().identifier != "us.tahsin.tooki",
        install_unavailable: crate::update_install::ensure_supported(&app).err(),
    }
}
