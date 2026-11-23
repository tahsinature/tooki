# Swift to Tauri migration

The primary Tooki app is now the Rust/Tauri implementation at the repository root. The complete previous Swift source, tests, resources, package manifests, build scripts and development/release notes are retained in `.playground/tooki-swift/`.

## Available in Tauri

| Area | Current implementation |
| --- | --- |
| Launcher | Root Search, application search, aliases, favorites, global shortcut assignments, shared window presentation and dismissal |
| Clipboard | Persistent history, search/filter, preview, copy/paste, pinning, file actions, grouping and Escape reset |
| Snippets | Settings editor, text/date/choice/input templates, automatic expansion on macOS, launcher preview and copy/paste. Further complexity is deferred. |
| Emoji | Bundled search by name/keywords/shortcode, category grid, 20 recent emoji, keyboard navigation, Copy/Paste/Copy Shortcode, shared Actions and settings assignments |
| Notes | Separate editor window, search, formatting, persistence, and note links |
| Keep Awake | Native assertions, timed sessions, commands, settings and configurable menu-bar icon |
| Hyper Key | Existing native/platform integration and settings |
| Shortcut Detective | Native shortcut observation and activity log |
| System Actions | Sleep, Empty Trash with shared confirmation, and eject |
| Appearance | Shared components, theme editing/import/export, launcher position, and production/development menu-bar icons |

## Remaining or deliberately deferred

- Swift menu-bar organizer: layout, reveal behavior, tint, and Thaw Bar. Reference `Sources/Tooki/Modules/MenuBar` in the archive.
- Search and activation of other apps' menu-bar items. Reference the archive's search mode and menu-bar adapters.
- In-app update checking/installing. The current Tauri release updates through Homebrew; Sparkle stays in the archive.
- Automatic emoji `:shortcode:` expansion. The picker can copy shortcodes, but the snippet listener is unchanged.
- Migration of existing Swift settings, clipboard history, snippets, recent emoji and shelves. This needs a separate data-migration decision. Original data remains untouched.
- Advanced snippet providers, scripts, community installation and import/export remain deferred.
- Full non-macOS feature parity and Intel/older-macOS runtime smoke checks. The macOS release is universal; cross-compilation alone does not verify those runtimes.

The archive is a comparison reference, not a second live backend. Continue migration from the relevant feature, reuse current shared components, and preserve existing data.
