use super::Application;
use std::process::Command;
pub fn scan() -> Result<Vec<Application>, String> {
    let output = Command::new("powershell.exe").args(["-NoProfile", "-NonInteractive", "-Command", "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new(); ConvertTo-Json -Compress -InputObject @(Get-StartApps | ForEach-Object { @{ id=$_.AppID; name=$_.Name } })"]).output().map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).into_owned());
    }
    serde_json::from_slice(&output.stdout).map_err(|e| e.to_string())
}
pub fn launch(id: &str) -> Result<(), String> {
    Command::new("explorer.exe")
        .arg(format!("shell:AppsFolder\\{id}"))
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}

pub fn location(id: &str) -> String {
    format!("shell:AppsFolder\\{id}")
}
pub fn reveal(id: &str) -> Result<(), String> {
    Command::new("explorer.exe")
        .arg(format!("/select,{}", location(id)))
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
pub fn can_uninstall(_: &str) -> bool {
    true
}
pub fn uninstall(_: &str) -> Result<(), String> {
    Command::new("explorer.exe")
        .arg("ms-settings:appsfeatures")
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
