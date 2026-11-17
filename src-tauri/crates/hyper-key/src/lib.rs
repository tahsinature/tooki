//! Native keyboard backends, independent of Tauri and feature UI.
#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
pub use windows::Session;

/// Explicitly exported for users to review and install. Never installed by Tooki.
pub const KEYD_CONFIG: &str = "# Tooki Hyper Key. Merge with existing keyd configuration if present.\n[ids]\n*\n\n[main]\ncapslock = overload(tooki_hyper, capslock)\n\n[tooki_hyper:C-A-S-M]\n";
