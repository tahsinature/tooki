use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager,
};

const ID: &str = "keep-awake";

pub fn update(app: &tauri::AppHandle, active: bool, visible: bool) -> Result<(), String> {
    if !active || !visible {
        app.remove_tray_by_id(ID);
        return Ok(());
    }
    if app.tray_by_id(ID).is_some() {
        return Ok(());
    }
    #[cfg(target_os = "macos")]
    {
        unsafe extern "C" {
            fn tooki_keep_awake_icon(pixels: *mut u8) -> bool;
        }
        let mut pixels = vec![0; 22 * 22 * 4];
        if !unsafe { tooki_keep_awake_icon(pixels.as_mut_ptr()) } {
            return Err("Could not create Keep Awake menu bar icon.".into());
        }
        let entries = [
            ("command:system.keepAwakeOff", "Turn Off Keep Awake"),
            ("command:system.keepAwake15", "15 Minutes"),
            ("command:system.keepAwake60", "1 Hour"),
            ("command:system.keepAwake120", "2 Hours"),
            ("command:system.keepAwakeOn", "Until Turned Off"),
            ("keep-awake-settings", "Keep Awake Settings…"),
        ];
        let menu = Menu::new(app).map_err(|e| e.to_string())?;
        for (id, title) in entries {
            let item =
                MenuItem::with_id(app, id, title, true, None::<&str>).map_err(|e| e.to_string())?;
            menu.append(&item).map_err(|e| e.to_string())?;
        }
        TrayIconBuilder::with_id(ID)
            .icon(tauri::image::Image::new_owned(pixels, 22, 22))
            .icon_as_template(true)
            .tooltip("Keep Awake is active")
            .menu(&menu)
            .on_menu_event(|app, event| {
                let result = if event.id.as_ref() == "keep-awake-settings" {
                    crate::settings_window::open_settings(app.clone(), Some("keepAwake".into()))
                } else {
                    super::execute(app, event.id.as_ref())
                };
                if let Err(error) = result {
                    eprintln!("Keep Awake: {error}");
                }
            })
            .build(app)
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn sync(app: &tauri::AppHandle) {
    let handle = app.clone();
    let _ = app.run_on_main_thread(move || {
        let state = handle.state::<super::KeepAwake>();
        let active = state
            .0
            .lock()
            .map(|value| value.session.is_some())
            .unwrap_or(false);
        let visible = state
            .1
            .lock()
            .map(|value| value.show_menu_bar_icon)
            .unwrap_or(false);
        if let Err(error) = update(&handle, active, visible) {
            eprintln!("Keep Awake: {error}");
        }
    });
}
