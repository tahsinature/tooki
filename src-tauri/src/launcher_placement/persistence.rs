use super::{
    geometry::{self, Point},
    sizing::Size,
    work, Placement,
};
use serde::{Deserialize, Serialize};
use tauri::{LogicalPosition, Manager, WebviewWindow};
#[derive(Serialize, Deserialize)]
struct Saved {
    monitor: Option<String>,
    x: f64,
    y: f64,
    #[serde(default)]
    size: Size,
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
        size: window
            .state::<Placement>()
            .sizing
            .lock()
            .map_err(|e| e.to_string())?
            .preferred,
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
    let size = if saved.size.valid() {
        saved.size
    } else {
        Size::default()
    };
    window
        .state::<Placement>()
        .sizing
        .lock()
        .map_err(|e| e.to_string())?
        .preferred = size;
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
    let fitted = size.fit(Size {
        width: w.width,
        height: w.height,
    });
    let pos = geometry::clamp(
        Point {
            x: w.x + saved.x * w.width,
            y: w.y + saved.y * w.height,
        },
        w,
        fitted.width,
        fitted.height,
    );
    window
        .set_position(LogicalPosition::new(pos.x, pos.y))
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn existing_position_files_keep_the_default_size() {
        let saved: Saved =
            serde_json::from_str(r#"{"monitor":"Built-in","x":0.2,"y":0.1}"#).unwrap();
        assert_eq!(saved.size, Size::default());
    }
    #[test]
    fn saved_dimensions_survive_serialization() {
        let saved = Saved {
            monitor: None,
            x: 0.2,
            y: 0.1,
            size: Size {
                width: 1024.0,
                height: 650.0,
            },
        };
        let restored: Saved = serde_json::from_slice(&serde_json::to_vec(&saved).unwrap()).unwrap();
        assert_eq!(restored.size, saved.size);
    }
}
