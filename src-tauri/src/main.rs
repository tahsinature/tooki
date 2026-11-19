#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod activity_log;
mod app_menu;
mod applications;
mod clipboard;
mod config;
mod emoji;
mod extensions;
mod filter_popup;
mod general_settings;
mod hyper;
mod instance_guard;
mod keep_awake;
mod launcher_placement;
mod launcher_presentation;
mod launcher_shortcut;
mod notes;
mod permissions;
mod platform;
mod popup_position;
mod settings_window;
#[allow(dead_code)]
mod shelf;
mod shortcut_detective;
mod snippets;
mod system_actions;
mod system_monitor;
mod tool_commands;
mod updates;
mod window_toggle;

use tauri::Manager;

#[tauri::command]
fn quit_app(app: tauri::AppHandle) {
    app.exit(0);
}

fn main() {
    let context = tauri::generate_context!();
    // Waiting for the other app pumps AppKit events. Do this before creating
    // webviews, so frontend IPC cannot run before managed services are ready.
    let _instance_guard = match instance_guard::acquire(&context.config().identifier) {
        Ok(guard) => guard,
        Err(error) => {
            eprintln!("Could not start Tooki: {error}");
            return;
        }
    };
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, args, _| {
            if !args.iter().any(|arg| {
                (arg.starts_with("tooki://")
                    || arg.starts_with("tooki-preview://")
                    || arg.starts_with("tooki-dev://"))
                    || arg == "--autostart"
            }) {
                if app.get_webview_window("main").is_some() {
                    let _ = settings_window::open_settings(app.clone(), None);
                }
            }
        }))
        .plugin(tauri_plugin_deep_link::init())
        .plugin(
            tauri_plugin_autostart::Builder::new()
                .arg("--autostart")
                .macos_launcher(tauri_plugin_autostart::MacosLauncher::LaunchAgent)
                .build(),
        )
        .manage(general_settings::GeneralSettings::default())
        .manage(filter_popup::FilterPopup::default())
        .manage(applications::Catalog::default())
        .manage(applications::preferences::Preferences::default())
        .manage(extensions::shelferry::Shelferry::default())
        .manage(shelf::Positions::default())
        .manage(shelf::Shelves::default())
        .manage(hyper::Hyper::default())
        .manage(shortcut_detective::Detective::default())
        .manage(launcher_placement::Placement::default())
        .manage(launcher_shortcut::LauncherShortcut::default())
        .manage(launcher_presentation::Presentation::default())
        .manage(system_actions::SystemActions::default())
        .manage(system_monitor::SystemMonitor::default())
        .manage(keep_awake::KeepAwake::default())
        .invoke_handler(tauri::generate_handler![
            quit_app,
            permissions::permission_request,
            updates::check_for_updates,
            updates::open_release_notes,
            config::portable_preferences,
            config::set_portable_preference,
            config::portable_themes,
            config::select_portable_theme,
            config::write_portable_theme,
            emoji::emoji_request,
            system_monitor::system_monitor_snapshot,
            system_monitor::open_activity_monitor,
            snippets::commands::snippet_request,
            tool_commands::execute_tool_command,
            tool_commands::command_availability,
            keep_awake::keep_awake_status,
            keep_awake::set_keep_awake_mode,
            keep_awake::set_keep_awake_icon,
            system_actions::pending_empty_trash,
            system_actions::confirm_empty_trash,
            system_actions::system_volumes,
            system_actions::eject_system_volume,
            system_actions::open_automation_settings,
            launcher_presentation::launcher_request_target,
            launcher_presentation::set_launcher_view,
            launcher_presentation::dismiss_launcher,
            launcher_presentation::return_to_root_search,
            platform::launcher::resize_launcher,
            launcher_presentation::launcher_frontend_ready,
            launcher_presentation::present_prepared_launcher,
            launcher_presentation::cancel_launcher_preparation,
            filter_popup::open_filter_popup,
            filter_popup::size_filter_popup,
            filter_popup::close_filter_popup,
            filter_popup::filter_popup_request,
            filter_popup::query_filter_popup,
            filter_popup::forward_filter_shortcut,
            general_settings::general_settings,
            general_settings::set_general_setting,
            app_menu::toggle_app_menu,
            app_menu::close_app_menu,
            app_menu::resize_app_menu,
            applications::list_applications,
            applications::launch_application,
            applications::preferences::application_preferences,
            applications::preferences::update_application_preference,
            applications::actions::application_action,
            clipboard::clipboard_request,
            notes::open_notes,
            notes::notes_request,
            platform::preview::close_preview,
            platform::window_chrome::set_window_corner_radius,
            platform::window_chrome::set_utility_on_top,
            platform::window_chrome::resize_utility_window,
            shelf::shelf_request,
            extensions::shelferry::shelferry_status,
            extensions::shelferry::configure_shelferry,
            extensions::shelferry::check_shelferry,
            hyper::hyper_request,
            activity_log::export_activity_log,
            shortcut_detective::detective_request,
            launcher_placement::launcher_drag_start,
            launcher_placement::launcher_drag_move,
            launcher_placement::launcher_drag_end,
            launcher_placement::launcher_guides,
            settings_window::open_settings,
            launcher_shortcut::get_launcher_shortcut,
            launcher_shortcut::set_launcher_shortcut,
            launcher_shortcut::set_shortcut_recording,
        ])
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_drag::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .on_window_event(|window, event| {
            if matches!(
                event,
                tauri::WindowEvent::CloseRequested { .. } | tauri::WindowEvent::Destroyed
            ) {
                platform::preview::close_window(window.app_handle(), window.label());
            }
            app_menu::handle_event(window, event);
            filter_popup::handle_event(window, event);
            settings_window::handle_event(window, event);
            notes::handle_event(window, event);

            launcher_placement::handle_event(window, event);
        })
        .setup(|app| {
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            config::initialize(app.handle())?;
            general_settings::initialize(app.handle());
            keep_awake::initialize(app.handle());
            applications::refresh(app.handle());
            settings_window::initialize(app.handle())?;
            platform::preview::initialize(app.handle());
            clipboard::start(app.handle())?;
            hyper::initialize(app.handle());
            snippets::initialize(app.handle());
            extensions::shelferry::initialize(app.handle());
            notes::initialize(app.handle())?;
            clipboard::start_ocr(app.handle());
            launcher_placement::restore(app.handle());
            launcher_shortcut::register(app.handle());
            applications::preferences::initialize(app.handle());
            config::start_watching(app.handle());
            permissions::initialize(app.handle());
            if !permissions::required()
                && !std::env::args().any(|arg| {
                    arg == "--autostart"
                        || (arg.starts_with("tooki://")
                            || arg.starts_with("tooki-preview://")
                            || arg.starts_with("tooki-dev://"))
                })
            {
                launcher_presentation::request(app.handle())?;
            }
            Ok(())
        })
        .build(context)
        .expect("Could not start Tooki")
        .run(|app, event| match event {
            tauri::RunEvent::ExitRequested { .. } => launcher_placement::remember(app),
            #[cfg(target_os = "macos")]
            tauri::RunEvent::Reopen { .. } => {
                if let Err(error) = settings_window::open_settings(app.clone(), None) {
                    eprintln!("Could not reopen Settings: {error}");
                }
            }
            tauri::RunEvent::Exit => {
                keep_awake::stop(app);
                notes::remember(app);
                hyper::stop(app);
                snippets::stop(app);

                shortcut_detective::stop(app);
                clipboard::cleanup(app);
            }
            _ => {}
        });
}
