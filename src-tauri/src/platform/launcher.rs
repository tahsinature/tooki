use tauri::WebviewWindow;

pub fn present(window: &WebviewWindow) -> tauri::Result<()> {
    #[cfg(target_os = "macos")]
    {
        let pointer = window.ns_window()? as usize;
        window.run_on_main_thread(move || unsafe {
            unsafe extern "C" {
                fn tooki_launcher_present(window: *mut std::ffi::c_void);
            }
            tooki_launcher_present(pointer as *mut _);
        })?;
    }
    #[cfg(not(target_os = "macos"))]
    {
        window.unminimize()?;
        window.show()?;
        window.set_focus()?;
    }
    Ok(())
}

pub fn dismiss(window: &WebviewWindow) -> tauri::Result<()> {
    #[cfg(target_os = "macos")]
    {
        let pointer = window.ns_window()? as usize;
        window.run_on_main_thread(move || unsafe {
            unsafe extern "C" {
                fn tooki_launcher_dismiss(window: *mut std::ffi::c_void);
            }
            tooki_launcher_dismiss(pointer as *mut _);
        })?;
    }
    #[cfg(not(target_os = "macos"))]
    window.hide()?;
    Ok(())
}

/// Complete the resize before a hidden launcher is allowed to become visible.
#[tauri::command]
pub async fn resize_launcher(window: WebviewWindow, width: f64, height: f64) -> Result<(), String> {
    if window.label() != "main"
        || !width.is_finite()
        || !height.is_finite()
        || !(680.0..=1600.0).contains(&width)
        || !(84.0..=1600.0).contains(&height)
    {
        return Err("Invalid launcher dimensions".into());
    }
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
    Ok(())
}
