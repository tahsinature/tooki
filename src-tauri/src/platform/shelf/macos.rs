unsafe extern "C" {
    fn tooki_shelf_watch(enabled: bool, callback: extern "C" fn(u8)) -> bool;
}
pub fn configure(
    app: &tauri::AppHandle,
    enabled: bool,
    callback: extern "C" fn(u8),
) -> Result<(), String> {
    let (tx, rx) = std::sync::mpsc::sync_channel(1);
    app.run_on_main_thread(move || {
        let result = unsafe { tooki_shelf_watch(enabled, callback) };
        let _ = tx.send(result);
    })
    .map_err(|e| e.to_string())?;
    if rx.recv().map_err(|e| e.to_string())? {
        Ok(())
    } else {
        Err("macOS could not start Shelf drag monitoring.".into())
    }
}
extern "C" fn ignored(_: u8) {}
pub fn stop() {
    // Called from Tauri's Exit event on the AppKit main thread.
    unsafe {
        tooki_shelf_watch(false, ignored);
    }
}
