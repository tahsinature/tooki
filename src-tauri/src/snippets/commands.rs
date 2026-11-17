use super::*;

#[tauri::command]
pub async fn snippet_request(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
    operation: String,
    args: Value,
) -> Result<Value, String> {
    if !["main", "settings"].contains(&window.label()) {
        return Err("Snippets are unavailable in this window.".into());
    }
    match operation.as_str() {
        "list" => {
            let (records, preferences) =
                with_store(&app, |store| Ok((store.list()?, store.preferences()?)))?;
            let status = native::call(&app, "status", json!({})).await?;
            Ok(json!({"records":records,"preferences":preferences,"status":status}))
        }
        "save" | "delete" | "preferences" => {
            if window.label() != "settings" {
                return Err("Edit snippets in Settings.".into());
            }
            let handle = app.clone();
            let action = operation.clone();
            let result = tauri::async_runtime::spawn_blocking(move || {
                with_store(&handle, |store| match action.as_str() {
                    "save" => Ok(json!(
                        store.save(serde_json::from_value(args).map_err(|e| e.to_string())?)?
                    )),
                    "delete" => {
                        store.delete(
                            args["id"].as_str().ok_or("Missing snippet")?,
                            args["revision"].as_i64().ok_or("Missing revision")?,
                        )?;
                        Ok(Value::Null)
                    }
                    _ => {
                        store.set_preferences(
                            &serde_json::from_value(args).map_err(|e| e.to_string())?,
                        )?;
                        Ok(Value::Null)
                    }
                })
            })
            .await
            .map_err(|e| e.to_string())??;
            configure(&app).await?;
            let _ = app.emit("snippets-changed", ());
            Ok(result)
        }
        "permission" | "recheck" => {
            if operation == "permission" {
                native::call(&app, "permission", json!({})).await?;
            }
            configure(&app).await
        }
        "preview" => {
            let record: Record =
                serde_json::from_value(args["record"].clone()).map_err(|e| e.to_string())?;
            Ok(json!(evaluate(
                &record,
                &args_map(&args)?,
                &Context::now()
            )?))
        }
        "begin" => {
            let pending = app.state::<Snippets>().pending.lock().unwrap().clone();
            if window.label() == "main" && pending.is_none() {
                let pid = native::call(&app, "target", json!({}))
                    .await
                    .unwrap_or(json!(0))
                    .as_i64()
                    .unwrap_or(0) as i32;
                *app.state::<Snippets>().target.lock().unwrap() = pid;
            }
            Ok(json!(pending))
        }
        "cancel" => {
            *app.state::<Snippets>().pending.lock().unwrap() = None;
            native::call(&app, "cancel", json!({})).await
        }
        "prepare" => {
            if window.label() != "main" {
                return Err("Run saved snippets from the launcher.".into());
            }
            let record = record(&app, args["id"].as_str().ok_or("Choose a snippet")?)?;
            if !record.configuration.enabled {
                return Err("This snippet is disabled.".into());
            }
            let result = evaluate(&record, &args_map(&args)?, &Context::now())?;
            let state = app.state::<Snippets>();
            let ticket = result.text.as_ref().map(|text| {
                let ticket = state.next_ticket.fetch_add(1, Ordering::Relaxed);
                let context = state
                    .pending
                    .lock()
                    .unwrap()
                    .as_ref()
                    .filter(|p| p.id == record.definition.id)
                    .map(|p| p.context.clone())
                    .unwrap_or_default();
                let mut prepared = state.prepared.lock().unwrap();
                if prepared.len() >= 32 {
                    prepared.pop_first();
                }
                prepared.insert(
                    ticket,
                    Prepared {
                        text: text.clone(),
                        id: record.definition.id,
                        revision: record.revision,
                        context,
                        pid: *state.target.lock().unwrap(),
                        created: Instant::now(),
                    },
                );
                ticket
            });
            Ok(json!({"text":result.text,"missing":result.missing,"ticket":ticket}))
        }
        "run" => {
            if window.label() != "main" {
                return Err("Run snippets from the launcher.".into());
            }
            runner::run(&app, &args).await?;
            Ok(Value::Null)
        }
        _ => Err("Unknown snippet operation.".into()),
    }
}
