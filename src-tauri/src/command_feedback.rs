//! One completion policy for immediate actions, independent of their entry point.
pub fn finish(
    app: &tauri::AppHandle,
    result: Result<(), String>,
    success: &str,
) -> Result<(), String> {
    match &result {
        Ok(()) => {
            // A presentation failure must not turn a completed operation into
            // an action error or invite the user to repeat it.
            if let Err(error) = crate::launcher_presentation::dismiss(app) {
                eprintln!("Could not dismiss launcher after command: {error}");
            }
            crate::platform::toast::show(app, success, false);
        }
        Err(error) => crate::platform::toast::show(app, error, true),
    }
    result
}
