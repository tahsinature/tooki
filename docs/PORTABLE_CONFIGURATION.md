# Portable configuration

The Rust desktop app stores portable preferences in `~/.config/tooki/`, resolving `~` to the current user's home directory. This directory is independent of the application's installation path.

| Path | Contents |
| --- | --- |
| `settings.json` | Versioned interface, theme selection, clipboard capture/retention, snippets, Hyper Key, menu-bar and integration preferences |
| `shortcuts.json` | Versioned launcher shortcut and application/tool assignments, aliases and favorites |
| `themes/<id>.json` | Individual custom theme definitions |
| `snippets/<id>.json` | Individual snippet definitions and personal configurations |
| `swift-snippet-migration.json` | Results of importing the older Swift snippet library |

The settings and shortcut documents have `"version": 1`. App assignments on macOS use `bundle:<bundle identifier>`; Tooki resolves these to the local installation. Assignments for missing applications remain saved. Tools use their existing `command:` identifiers.

Tooki writes these files directly from Settings. External changes are checked every two seconds, including when Settings is closed. Files are written atomically, with private file permissions on Unix. Existing file and directory symlinks are preserved. Keep symlink targets available; broken links are reported rather than replaced.

Use your preferred file sync or private dotfiles system to distribute this directory. Tooki does not provide a cloud sync service. Snippet configurations can contain personal information. Avoid publishing them accidentally. Exclude temporary files and migration staging directories from synchronization.

## Migration

On first use, an empty destination receives the Rust app's existing settings and snippet records. Existing destination settings take precedence. WebKit local-storage values and original native configuration/SQLite files are retained. A local migration marker allows an interrupted initial migration to resume.

The older Swift `config.json` is not interpreted or modified. If a Swift `snippets.json` is present, its entries are imported once with stable `swift-` identifiers. Text, date/time and supported argument fields are converted. Unsupported placeholders, triggers and trigger conflicts produce disabled entries with review notes. The original file is retained, and `swift-snippet-migration.json` records the outcome. The `swiftSnippetsImported` setting prevents deleted imports from reappearing on another computer.

## Conflicts and errors

Invalid JSON and unsupported document versions are reported without overwriting the file. Invalid snippet libraries are not applied to automatic expansion. Reopen a snippet or theme editor if its file changed externally while editing; stale saves are rejected using content checks, not revision counters shared between machines.

Atomic writes and stale-edit detection do not provide distributed conflict merging. Two computers editing the same file before either receives the other's changes still require the sync provider's conflict handling. Keep conflict copies until you have reconciled them. A theme or snippet filename must match its identifier; unexpected conflict copies produce an error rather than silently replacing an entry.

## Local data

The app's Application Support and WebKit directories still contain machine-specific state and migration originals. These are not part of portable configuration:

- Notes content, clipboard history/images, emoji recents and usage data.
- Window geometry and local navigation state.
- Launch-at-login registration, Accessibility permissions and active Keep Awake sessions.
- Shelferry executable overrides and Hyper Key recovery information.
- Whether clipboard history is persisted between launches. This stays local so another computer cannot switch this Mac's history storage policy.

Shelferry continues to own its data and configuration. Tooki syncs only whether its integration is enabled.
