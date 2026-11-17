//! Operations that release storage before opening menus, dialogs or other native UI.
use super::{conversion, request, required};
use serde_json::{json, Value};
use tauri::Manager;
use tauri_plugin_clipboard_manager::ClipboardExt;
use tauri_plugin_dialog::DialogExt;
pub fn handles(operation: &str) -> bool {
    matches!(
        operation,
        "preview"
            | "previewUpdate"
            | "updateConversionPreview"
            | "discardConversion"
            | "previewConversion"
            | "conversionApps"
            | "openConversion"
            | "refreshConversion"
            | "toggleAll"
            | "choose"
            | "paste"
            | "pasteText"
            | "pasteDrop"
            | "copyPaths"
            | "revealAll"
            | "selection"
    )
}
pub fn run(app: &tauri::AppHandle, operation: &str, mut args: Value) -> Result<Value, String> {
    let owner = args["previewOwner"].as_str().unwrap_or("main").to_owned();
    if matches!(operation, "preview" | "previewUpdate") {
        let context = format!("shelf:{}", required(&args, "shelf")?);
        let update = operation == "previewUpdate";
        if update && !crate::platform::preview::active(app, &owner, &context)? {
            return Ok(Value::Null);
        }
        let library = request(app, "list", json!({}))?;
        let shelf = library["shelves"]
            .as_array()
            .unwrap()
            .iter()
            .find(|s| s["id"] == args["shelf"])
            .ok_or("Shelf not found")?;
        let paths: Vec<_> = shelf["items"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|item| match args["items"].as_array() {
                Some(ids) => ids.contains(&item["id"]),
                None => args["item"].is_null() || args["item"] == item["id"],
            })
            .map(|item| item["path"].clone())
            .collect();
        return crate::platform::preview::show(app, &owner, &context, json!(paths), update);
    }
    if operation == "discardConversion" {
        #[cfg(target_os = "macos")]
        crate::clipboard::native::on_main(
            app,
            "previewClose",
            json!({
                "owner":owner,"context":format!("conversion:{}", required(&args, "session")?)
            }),
        )?;
        conversion::discard(required(&args, "session")?);
        return Ok(Value::Null);
    }
    if matches!(
        operation,
        "previewConversion"
            | "updateConversionPreview"
            | "conversionApps"
            | "openConversion"
            | "refreshConversion"
    ) {
        let session = required(&args, "session")?;
        let index = args["index"].as_u64().unwrap_or(0) as usize;
        if operation == "refreshConversion" {
            return conversion::refresh_preview(session, index);
        }
        let context = format!("conversion:{session}");
        if operation == "updateConversionPreview"
            && !crate::platform::preview::active(app, &owner, &context)?
        {
            return Ok(Value::Null);
        }
        let paths = conversion::preview_paths(session)?;
        let path = paths.get(index).ok_or("Select a conversion preview")?;
        if matches!(operation, "previewConversion" | "updateConversionPreview") {
            return crate::platform::preview::show(
                app,
                &owner,
                &context,
                json!([path]),
                operation == "updateConversionPreview",
            );
        }
        return crate::platform::file_action(
            app,
            match operation {
                "conversionApps" => "apps",
                "openConversion" => "open",
                _ => "preview",
            },
            path,
            args["app"].as_str(),
        );
    }
    if operation == "toggleAll" {
        let library = request(app, "list", json!({}))?;
        if library["settings"]["enabled"] != true {
            return Err("Shelf is disabled. Enable it in Settings → Shelf.".into());
        }
        if library["shelves"].as_array().is_some_and(|s| s.is_empty()) {
            let id = request(app, "create", json!({"name":"Shelf"}))?;
            return request(app, "show", json!({"shelf":id}));
        }
        let visible = app.webview_windows().iter().any(|(label, window)| {
            label.starts_with("shelf-") && window.is_visible().unwrap_or(false)
        });
        for shelf in library["shelves"].as_array().unwrap() {
            let id = shelf["id"].as_str().unwrap();
            if visible {
                if let Some(w) = app.get_webview_window(&format!("shelf-{id}")) {
                    crate::platform::preview::close_window(app, w.label());
                    let _ = w.hide();
                }
            } else {
                request(app, "show", json!({"shelf":id}))?;
            }
        }
        return Ok(Value::Null);
    }
    if operation == "choose" {
        let files = app.dialog().file().blocking_pick_files();
        let Some(files) = files else {
            return Ok(Value::Null);
        };
        let paths: Result<Vec<_>, _> = files.into_iter().map(|f| f.into_path()).collect();
        args["paths"] = json!(paths.map_err(|e| e.to_string())?);
        return request(app, "addFiles", args);
    }
    if matches!(operation, "paste" | "pasteText" | "pasteDrop") {
        let content = crate::platform::shelf::content::pasteboard(app, operation == "pasteDrop")?;
        if content["files"].is_array() {
            args["paths"] = content["files"].clone();
            return request(app, "addFiles", args);
        }
        args["content"] = content;
        return request(app, "addContent", args);
    }
    if matches!(operation, "copyPaths" | "revealAll" | "selection") {
        let library = request(app, "list", json!({}))?;
        let shelf = library["shelves"]
            .as_array()
            .unwrap()
            .iter()
            .find(|s| s["id"] == args["shelf"])
            .ok_or("Shelf not found")?;
        let ids = args["items"].as_array();
        let items: Vec<_> = shelf["items"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|i| ids.is_none_or(|ids| ids.contains(&i["id"])))
            .collect();
        let action = if operation == "selection" {
            required(&args, "action")?
        } else if operation == "revealAll" {
            "reveal"
        } else {
            "copyPath"
        };
        if matches!(action, "copyPath" | "copyOriginalPath") {
            let key = if action == "copyPath" {
                "path"
            } else {
                "originalPath"
            };
            let paths = items
                .iter()
                .filter_map(|i| i[key].as_str())
                .collect::<Vec<_>>()
                .join("\n");
            app.clipboard()
                .write_text(paths)
                .map_err(|e| e.to_string())?;
        } else if action == "preview" {
            return request(app, "preview", args);
        } else if cfg!(target_os = "macos") && action == "copyFile" {
            let paths: Vec<_> = items.iter().map(|i| i["path"].clone()).collect();
            crate::clipboard::native::on_main(
                app,
                "copy",
                json!({"paths":paths,"item":{"files":paths}}),
            )?;
        } else {
            for item in items {
                let mut payload = args.clone();
                payload["item"] = item["id"].clone();
                request(app, action, payload)?;
            }
        }
        return Ok(Value::Null);
    }
    Err("Unknown Shelf action".into())
}
