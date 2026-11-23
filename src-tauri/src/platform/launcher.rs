use tauri::WebviewWindow;

/// Complete the resize before a hidden launcher is allowed to become visible.
#[tauri::command]
pub async fn resize_launcher(
    window: WebviewWindow,
    mode: crate::launcher_placement::sizing::Mode,
    header_height: f64,
) -> Result<(), String> {
    if window.label() != "main"
        || !header_height.is_finite()
        || !(44.0..=80.0).contains(&header_height)
    {
        return Err("Invalid launcher dimensions".into());
    }
    let crate::launcher_placement::sizing::Size { width, height } =
        crate::launcher_placement::requested_size(&window, mode, header_height)?;
    #[cfg(target_os = "macos")]
    {
        let pointer = window.ns_window().map_err(|e| e.to_string())? as usize;
        let (done, completion) = tokio::sync::oneshot::channel();
        window
            .run_on_main_thread(move || {
                unsafe {
                    unsafe extern "C" {
                        fn tooki_launcher_resize(
                            window: *mut std::ffi::c_void,
                            width: f64,
                            height: f64,
                        );
                    }
                    tooki_launcher_resize(pointer as *mut _, width, height);
                }
                let _ = done.send(());
            })
            .map_err(|e| e.to_string())?;
        completion.await.map_err(|e| e.to_string())?;
    }
    #[cfg(not(target_os = "macos"))]
    {
        let position = window.outer_position().map_err(|e| e.to_string())?;
        window
            .set_size(tauri::LogicalSize::new(width, height))
            .map_err(|e| e.to_string())?;
        window.set_position(position).map_err(|e| e.to_string())?;
    }
    crate::launcher_placement::applied_size(&window, mode)
}
