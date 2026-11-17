//! Allowlisted Shelf links. No shell execution; destructive links require confirmation.
use super::{
    model::{name, Library},
    request,
};
use serde_json::json;
use tauri::{Manager, Url};
use tauri_plugin_deep_link::DeepLinkExt;
use tauri_plugin_dialog::{DialogExt, MessageDialogButtons};
#[derive(Debug, PartialEq)]
struct Command {
    verb: String,
    shelf: Option<String>,
    paths: Vec<String>,
    copy: bool,
}
fn parse(url: &Url) -> Result<Command, String> {
    if !["tooki", "tooki-preview"].contains(&url.scheme())
        || url.host_str() != Some("shelf")
        || !url.username().is_empty()
        || url.password().is_some()
        || url.port().is_some()
        || url.fragment().is_some()
    {
        return Err("Unsupported Shelf link.".into());
    }
    let verb = url.path().trim_matches('/');
    if !["new", "add", "show", "hide", "toggle", "clear"].contains(&verb) {
        return Err("Unknown Shelf command.".into());
    }
    let mut command = Command {
        verb: verb.into(),
        shelf: None,
        paths: vec![],
        copy: false,
    };
    for (key, value) in url.query_pairs() {
        match key.as_ref() {
            "shelf" if !value.is_empty() => command.shelf = Some(name(&value)?),
            "mode" if value == "copy" => command.copy = true,
            "mode" if value == "original" => command.copy = false,
            "path" if !value.is_empty() && !value.chars().any(char::is_control) => {
                if !std::path::Path::new(value.as_ref()).is_absolute() && !value.starts_with("~/") {
                    return Err("Shelf links require absolute file paths.".into());
                }
                command.paths.push(value.into_owned());
            }
            _ => return Err("Invalid Shelf link parameter.".into()),
        }
    }
    if command.paths.len() > 100 || (verb == "add" && command.paths.is_empty()) {
        return Err("Choose between 1 and 100 paths.".into());
    }
    if verb != "add" && (!command.paths.is_empty() || command.copy) {
        return Err("Paths and copy mode are only valid for add.".into());
    }
    Ok(command)
}
fn create(app: &tauri::AppHandle, name: &str) -> Result<String, String> {
    request(app, "create", json!({"name":name}))?
        .as_str()
        .map(str::to_owned)
        .ok_or("Missing Shelf id".into())
}
fn execute(app: &tauri::AppHandle, command: Command) -> Result<(), String> {
    let data = request(app, "list", json!({}))?;
    let library: Library = serde_json::from_value(data).map_err(|e| e.to_string())?;
    if !library.settings.enabled {
        return Err("Enable Shelf in Settings first.".into());
    }
    if command.verb == "new" {
        let id = create(app, command.shelf.as_deref().unwrap_or("New Shelf"))?;
        return request(app, "show", json!({"shelf":id})).map(|_| ());
    }
    let matches: Vec<_> = library
        .shelves
        .iter()
        .filter(|s| {
            command
                .shelf
                .as_ref()
                .is_none_or(|r| s.id == *r || s.name == *r)
        })
        .collect();
    if command.shelf.is_some() && matches.len() > 1 {
        return Err("Several shelves have this name. Use the shelf id.".into());
    }
    if command.verb == "add" {
        let mut paths = vec![];
        for path in command.paths {
            let path = if let Some(relative) = path.strip_prefix("~/") {
                app.path()
                    .home_dir()
                    .map_err(|e| e.to_string())?
                    .join(relative)
            } else {
                path.into()
            };
            if !path.exists() {
                return Err("A file in this Shelf link no longer exists.".into());
            }
            paths.push(path);
        }
        let id = if command.shelf.as_deref() == Some("new") {
            create(app, "New Shelf")?
        } else if let Some(shelf) = matches.last() {
            shelf.id.clone()
        } else {
            create(app, command.shelf.as_deref().unwrap_or("New Shelf"))?
        };
        request(
            app,
            "addFiles",
            json!({"shelf":id,"paths":paths,"copy":command.copy}),
        )?;
        return request(app, "show", json!({"shelf":id})).map(|_| ());
    }
    if matches.is_empty() && command.shelf.is_some() {
        return Err("Shelf not found.".into());
    }
    if matches.is_empty() && command.verb == "toggle" {
        let id = create(app, "New Shelf")?;
        return request(app, "show", json!({"shelf":id})).map(|_| ());
    }
    if command.verb == "clear" && !matches.is_empty() {
        let confirmed = app.dialog().message("This link will delete the selected shelves and Tooki-owned copies. Original files stay untouched.")
            .title("Clear shelves?").buttons(MessageDialogButtons::OkCancelCustom("Clear Shelves".into(), "Cancel".into())).blocking_show();
        if !confirmed {
            return Ok(());
        }
    }
    let hide = command.verb == "hide"
        || (command.verb == "toggle"
            && matches.iter().any(|s| {
                app.get_webview_window(&format!("shelf-{}", s.id))
                    .is_some_and(|w| w.is_visible().unwrap_or(false))
            }));
    for shelf in matches {
        if hide {
            if let Some(w) = app.get_webview_window(&format!("shelf-{}", shelf.id)) {
                crate::platform::preview::close_window(app, w.label());
                w.hide().map_err(|e| e.to_string())?;
            }
        } else {
            request(
                app,
                if command.verb == "clear" {
                    "deleteShelf"
                } else {
                    "show"
                },
                json!({"shelf":shelf.id}),
            )?;
        }
    }
    Ok(())
}
pub fn initialize(app: &tauri::AppHandle) {
    let (tx, rx) = std::sync::mpsc::channel::<Url>();
    // Read startup links before installing the listener; setup runs on the event loop.
    if let Ok(Some(urls)) = app.deep_link().get_current() {
        for url in urls {
            let _ = tx.send(url);
        }
    }
    app.deep_link().on_open_url(move |event| {
        for url in event.urls() {
            let _ = tx.send(url);
        }
    });
    let app = app.clone();
    std::thread::spawn(move || {
        for url in rx {
            if url.host_str() != Some("shelf") {
                continue;
            }
            app.dialog()
                .message(super::LEGACY_NOTICE)
                .title("Shelf link")
                .show(|_| {});
        }
    });
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_encoded_paths_and_names() {
        let c = parse(&Url::parse("tooki-preview://shelf/add?path=~%2Fmy%20file.txt&path=~%2Fb&mode=copy&shelf=Work%20files").unwrap()).unwrap();
        assert!(parse(&Url::parse("tooki://shelf/new").unwrap()).is_ok());
        assert_eq!(c.paths, vec!["~/my file.txt", "~/b"]);
        assert!(c.copy);
        assert_eq!(c.shelf.as_deref(), Some("Work files"));
    }
    #[test]
    fn rejects_untrusted_commands_and_relative_paths() {
        for url in [
            "untrusted://shelf/new",
            "tooki-preview://run/shell",
            "tooki-preview://shelf/execute",
            "tooki-preview://shelf/add?path=relative",
            "tooki-preview://shelf/add",
            "tooki-preview://shelf/clear?path=/tmp/file",
            "tooki-preview://user@shelf/new",
        ] {
            assert!(parse(&Url::parse(url).unwrap()).is_err(), "{url}");
        }
    }
}
