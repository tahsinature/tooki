use super::{
    geometry::{self, Point},
    work,
};
use serde::{Deserialize, Serialize};
use tauri::{LogicalPosition, Manager, WebviewWindow};
#[derive(Serialize, Deserialize)]
struct Saved {
    monitor: Option<String>,
    x: f64,
    y: f64,
}
fn path(window: &WebviewWindow) -> Result<std::path::PathBuf, String> {
    let dir = window
        .app_handle()
        .path()
        .app_config_dir()
        .map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("launcher-position.json"))
}
pub fn save(window: &WebviewWindow) -> Result<(), String> {
    let Some(m) = window.current_monitor().map_err(|e| e.to_string())? else {
        return Ok(());
    };
    let pos = window.outer_position().map_err(|e| e.to_string())?;
    let pos = pos.to_logical::<f64>(window.scale_factor().map_err(|e| e.to_string())?);
    let w = work(&m);
    let saved = Saved {
        monitor: m.name().cloned(),
        x: (pos.x - w.x) / w.width,
        y: (pos.y - w.y) / w.height,
    };
    let path = path(window)?;
    let temp = path.with_extension("tmp");
    std::fs::write(
        &temp,
        serde_json::to_vec(&saved).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    std::fs::rename(temp, path).map_err(|e| e.to_string())
}
pub fn restore(window: &WebviewWindow) -> Result<(), String> {
    let path = path(window)?;
    if !path.exists() {
        return Ok(());
    }
    let saved: Saved = serde_json::from_slice(&std::fs::read(path).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    if !saved.x.is_finite() || !saved.y.is_finite() {
        return Err("Invalid saved launcher position".into());
    }
    let monitors = window.available_monitors().map_err(|e| e.to_string())?;
    let primary = window.primary_monitor().map_err(|e| e.to_string())?;
    let Some(m) = monitors
        .iter()
        .find(|m| m.name().cloned() == saved.monitor)
        .or(primary.as_ref())
    else {
        return Ok(());
    };
    let w = work(m);
    let pos = geometry::clamp(
        Point {
            x: w.x + saved.x * w.width,
            y: w.y + saved.y * w.height,
        },
        w,
        760.0,
        520.0,
    );
    window
        .set_position(LogicalPosition::new(pos.x, pos.y))
        .map_err(|e| e.to_string())
}
