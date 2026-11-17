#[cfg(target_os = "macos")]
pub fn start(window: tauri::WebviewWindow, items: serde_json::Value) -> Result<bool, String> {
    use std::{
        ffi::{c_char, c_void, CString},
        sync::mpsc::{sync_channel, SyncSender},
    };
    unsafe extern "C" {
        fn tooki_shelf_drag(
            window: *mut c_void,
            input: *const c_char,
            context: *mut c_void,
            callback: extern "C" fn(*mut c_void, bool),
        ) -> bool;
    }
    extern "C" fn completed(context: *mut c_void, dropped: bool) {
        let sender = unsafe { Box::from_raw(context as *mut SyncSender<Result<bool, String>>) };
        let _ = sender.send(Ok(dropped));
    }
    let input = CString::new(items.to_string()).map_err(|e| e.to_string())?;
    let (tx, rx) = sync_channel(1);
    let handle = window.clone();
    window
        .run_on_main_thread(move || {
            let pointer = match handle.ns_window() {
                Ok(pointer) => pointer,
                Err(e) => {
                    let _ = tx.send(Err(e.to_string()));
                    return;
                }
            };
            let context = Box::into_raw(Box::new(tx));
            if !unsafe {
                tooki_shelf_drag(pointer, input.as_ptr(), context as *mut c_void, completed)
            } {
                let tx = unsafe { Box::from_raw(context) };
                let _ = tx.send(Err("Could not start this drag. Please try again.".into()));
            }
        })
        .map_err(|e| e.to_string())?;
    rx.recv().map_err(|e| e.to_string())?
}
