pub mod sampling;
use sampling::Sampler;
use serde_json::Value;
use std::sync::Mutex;
use tauri::Manager;
#[derive(Default)]
pub struct SystemMonitor(Mutex<Sampler>);

#[tauri::command]
pub async fn system_monitor_snapshot(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    session: String,
) -> Result<Option<Value>, String> {
    if window.label() != "main" {
        return Err("Open System Monitor from the launcher.".into());
    }
    if !window.is_visible().map_err(|e| e.to_string())? {
        return Ok(None);
    }
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<SystemMonitor>();
        let mut sampler = state.0.lock().map_err(|e| e.to_string())?;
        let raw = crate::platform::system_monitor::snapshot()?;
        Ok(Some(sampler.sample(session, raw)))
    })
    .await
    .map_err(|e| e.to_string())?
}
#[tauri::command]
pub async fn open_activity_monitor(app: tauri::AppHandle) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(|| {
        crate::platform::system_monitor::open_activity_monitor()
    })
    .await
    .map_err(|e| e.to_string())??;
    crate::launcher_presentation::dismiss_launcher(app)
}
#[cfg(all(test, target_os = "macos"))]
mod tests {
    #[test]
    fn native_snapshot_contains_real_cpu_and_memory() {
        let raw = crate::platform::system_monitor::snapshot().unwrap();
        assert!(!raw.cpu_ticks.is_empty());
        assert!(raw.details["memoryTotal"].as_u64().unwrap() > 0);
        assert!(!raw.processes.is_empty());
        assert!(
            raw.details["storage"]["available"].as_u64().unwrap()
                <= raw.details["storage"]["total"].as_u64().unwrap()
        );
    }
}
