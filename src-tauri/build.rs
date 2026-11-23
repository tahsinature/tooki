fn main() {
    println!("cargo:rerun-if-env-changed=TOOKI_BUILD_TIMESTAMP");
    println!("cargo:rerun-if-env-changed=BUILD_NUMBER");
    println!("cargo:rerun-if-changed=src");
    println!("cargo:rerun-if-changed=../src");
    let built_at = std::env::var("TOOKI_BUILD_TIMESTAMP")
        .map(|value| {
            value
                .parse::<u64>()
                .expect("TOOKI_BUILD_TIMESTAMP must be Unix seconds")
        })
        .unwrap_or_else(|_| {
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        });
    println!("cargo:rustc-env=TOOKI_BUILD_TIMESTAMP={built_at}");
    println!(
        "cargo:rustc-env=TOOKI_BUILD_NUMBER={}",
        std::env::var("BUILD_NUMBER").unwrap_or_default()
    );
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        cc::Build::new()
            .file("native/instance_guard.m")
            .file("native/permissions.m")
            .file("native/clipboard.m")
            .file("native/emoji.m")
            .file("native/system_monitor.m")
            .file("native/settings_chrome.m")
            .file("native/utility_window.m")
            .file("native/preview.m")
            .file("native/launcher.m")
            .file("native/toast.m")
            .file("native/applications.m")
            .file("native/system_actions.m")
            .file("native/keep_awake.m")
            .file("native/menu_bar_icon.m")
            .file("native/snippets.m")
            .file("native/hyper.m")
            .file("native/shelf.m")
            .file("native/shelf_files.m")
            .file("native/shelf_conversion.m")
            .file("native/shelf_drag.m")
            .flag("-fobjc-arc")
            .flag("-fblocks")
            .compile("tooki_clipboard");
        for framework in [
            "IOKit",
            "SystemConfiguration",
            "CoreText",
            "AppKit",
            "Carbon",
            "Foundation",
            "Vision",
            "Quartz",
            "QuickLookThumbnailing",
            "ImageIO",
            "ApplicationServices",
        ] {
            println!("cargo:rustc-link-lib=framework={framework}");
        }
        println!("cargo:rerun-if-changed=native/instance_guard.m");
        println!("cargo:rerun-if-changed=native/permissions.m");
        println!("cargo:rerun-if-changed=native/permissions.h");
        println!("cargo:rerun-if-changed=native/clipboard.m");
        println!("cargo:rerun-if-changed=native/emoji.m");
        println!("cargo:rerun-if-changed=native/system_monitor.m");
        println!("cargo:rerun-if-changed=native/settings_chrome.m");
        println!("cargo:rerun-if-changed=native/utility_window.m");
        println!("cargo:rerun-if-changed=native/preview.m");
        println!("cargo:rerun-if-changed=native/launcher.m");
        println!("cargo:rerun-if-changed=native/toast.m");
        println!("cargo:rerun-if-changed=native/applications.m");
        println!("cargo:rerun-if-changed=native/system_actions.m");
        println!("cargo:rerun-if-changed=native/keep_awake.m");
        println!("cargo:rerun-if-changed=native/menu_bar_icon.m");
        println!("cargo:rerun-if-changed=native/snippets.m");
        println!("cargo:rerun-if-changed=native/snippet_insertion.h");
        println!("cargo:rerun-if-changed=native/hyper.m");
        println!("cargo:rerun-if-changed=native/shelf.m");
        println!("cargo:rerun-if-changed=native/shelf_files.m");
        println!("cargo:rerun-if-changed=native/shelf_conversion.m");
        println!("cargo:rerun-if-changed=native/shelf_drag.m");
    }
    tauri_build::build()
}
