# Desktop prototype

The independent prototype lives in `prototypes/desktop` on branch `prototype/tauri-root-clipboard`. It uses Tauri 2, Rust, Svelte 5, TypeScript, Tailwind 4 and Vite. It contains no Asyar implementation or AI features.

## Run

Use Bun 1.4.2 (recorded in `package.json`) and the Rust toolchain. Bun runs the JavaScript tooling and tests; Cargo still compiles the native host. `bun.lock` records dependency versions. CI can use `bun install --frozen-lockfile`.

```sh
cd prototypes/desktop
bun install
bun run desktop
```

Keep the command running. Svelte and CSS edits update the open window through Vite. Rust changes require rebuilding the native host. The first native build downloads and compiles dependencies; subsequent frontend edits do not repeat that work.

For browser-only development, use `bun run dev` and open `http://127.0.0.1:1421`.

### macOS development signing

The macOS configuration signs packaged apps with the existing **Tooki Dev Signing** certificate. The Cargo runner in `.cargo/config.toml` signs the development executable before each launch, including Rust rebuilds under `make dev` or `bun run tauri dev`. Both use the identifier `us.tahsin.tooki.preview`, so code changes keep the same certificate-based signing requirement instead of an ad-hoc executable hash. Run Cargo from `prototypes/desktop` or `src-tauri` so it discovers this configuration. Tests and examples pass through the runner unchanged; Windows and Linux do not use it.

The certificate and its private key must be available in the login keychain. Set `APPLE_SIGNING_IDENTITY` to override it for both development launches and packaging. A missing certificate fails signing instead of silently falling back to ad-hoc signing. Direct `cargo build` and `tauri build --no-bundle` only compile; use the development launcher or an app bundle when testing persistent macOS permissions.

After switching from an ad-hoc build, macOS may request folder access or Accessibility again. Grant the required permission to the new signed build. No privacy database resets or broader filesystem permissions are needed. This local certificate is for development; public distribution needs its own signing and notarization setup.

## Global shortcut

Command+Space on macOS (Control+Space elsewhere) shows and focuses the preview, or hides it when already focused. The current screen is preserved and search receives focus. Keep the process running. If registration fails, the terminal reports the error; free the shortcut in the competing launcher or system settings and restart the preview. Browser-only mode has no global shortcut.

## Included

- Root command search with working navigation into Clipboard History, all clips, pinned clips and links.
- Clipboard list/detail view with synthetic text, link and code records.
- Shared search header, result row, group heading, keycap, footer and action popup components.
- Search, type filtering, pin/unpin, hover feedback and explicit copying to the system clipboard.
- Arrow navigation, Page Up/Down, Command+Up/Down, Return, Command+K and Command+Escape. Control equivalents work for non-Mac keyboards.
- Empty results and first/last-row scroll handling.

Use Return from the search field or double-click a row to open/copy. Single-click selects a row. Pin changes are in memory and reset when the app restarts.

## Isolation and limits

The app identity is `us.tahsin.tooki.preview`. It does not access production Tooki settings, history or services. Clipboard permission permits writing text only, triggered by Copy. It does not monitor or read the system clipboard.

Root Search currently searches prototype commands, not installed applications. The prototype does not provide paste into another app, images, native materials, a menu-bar presence, persistent history or production updating. Its normal desktop window is intentional for this first interface evaluation. Windows/Linux runtime behavior has not been verified.

The Rust host initializes Tauri and the official clipboard plugin. Presentation state and sample data remain in TypeScript. This is a minimal foundation, not the final service or extension architecture.

## Structure

- `src/components`: shared presentation components used across the screens.
- `src/lib`: synthetic fixtures and keyboard navigation logic.
- `src/App.svelte`: screen state and shared keyboard routing.
- `src/style.css`: shared visual tokens and styles.
- `src-tauri`: native host, capabilities and desktop configuration.

## Checks

```sh
bun run check
bun test
bun run build
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

Frontend validation is independent of the Swift application. Existing Swift build commands remain unchanged.

## Hyper Key and Shelf native boundaries

The prototype now separates feature workflows from OS adapters:

- `src-tauri/src/hyper` owns settings, startup, shutdown, status, and helper export. Its adapter calls the macOS bridge or the independent Windows `hyper-key` crate. The frontend only requests status or changes the enabled preference.
- `src-tauri/src/platform` owns native file actions and reports capabilities. Shelf hides unavailable native actions instead of displaying nonfunctional controls.
- `src-tauri/src/shelf` owns persistence, references versus owned copies, import rollback, and independent floating windows. It does not depend on AppKit. Every floating window has its own `shelf-{id}` label. Moving it uses that window's native drag operation, never launcher placement state.
- The shared Svelte panels, rows, search header, action menu and footer are reused by Shelf. Clipboard's “Add Copy to Shelf” materializes independent copies so clipboard retention cannot remove Shelf content.

### Hyper Key

Hold Caps Lock while pressing another key for Control + Alt/Option + Shift + Super/Command. On macOS and Windows a quick unused tap toggles Caps Lock. Enable it in Settings → Hyper Key. It defaults off.

| Platform | Implementation | Verification and limits |
| --- | --- | --- |
| macOS | HID Caps Lock → F18 mapping plus a native event tap, Accessibility required | Native build and mapping-parser fixture tests pass. Physical keyboard behavior still requires a live test. Existing Caps Lock remappers must be disabled first. Recovery data restores Tooki's mapping on normal quit or the next launch after a crash. F18 is reserved while enabled. |
| Windows | Dedicated low-level hook thread with tagged modifier injection and teardown | Backend cross-compiles. Runtime testing still needed on Windows. Elevated apps and secure desktops are outside normal input injection. |
| Linux | Optional keyd configuration export | No privileged installation, service enablement or system configuration changes are performed by Tooki. Configuration follows keyd's documented `overload` and modifier-layer syntax. Runtime validation still needed on Linux. Tap behavior follows keyd. |

Linux users install keyd separately, review/merge the exported configuration, validate with `keyd check`, and reload the service. Do not overwrite an existing keyd configuration or introduce overlapping device matches. Remove Tooki's bindings and reload to disable; the helper runs independently of Tooki. Reference: [keyd manual](https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc).

### Shelf Manager

Open **Shelf Manager** from root search, then Actions → New Shelf. Add file references, independent file copies, clipboard text, or drop files into an open shelf. Clipboard Actions → Add Copy to Shelf supports text, images and file clips. The manager provides search, reference/copy filters, file renaming, removal, opening, path copying, and floating windows.

macOS additionally provides native Quick Look, application discovery/Open With, and file pasteboard copying. Windows/Linux currently provide opening/revealing through the system file manager; their native preview, application chooser and file-copy adapters remain unavailable. macOS outgoing drags publish file URLs and, for captured text/links, rich pasteboard payloads. Windows/Linux use the existing drag plugin and need live verification on those systems.

Removing a reference never removes the source file. Removing an owned item removes only its app-owned copy. Item renaming changes the actual file name and updates matching references. It refuses to overwrite an existing file and restores the original name if saving the library fails. The library lives in the prototype's app-data `shelf` directory, separate from Swift Tooki. A backup is retained during library replacement; malformed data produces an error rather than resetting the library.

This is a manager and floating-shelf implementation, not full Swift Shelf parity. macOS image conversion is implemented. Windows/Linux global drag-trigger, conversion and native file-action parity remain future work. Existing Clipboard capture is still macOS-specific.

Focused checks:

```sh
cd prototypes/desktop
bun run check
bun test
make test-shelf
make test-hyper-native
cargo check --manifest-path src-tauri/crates/hyper-key/Cargo.toml --target x86_64-pc-windows-gnu
```

A packaged macOS UI smoke test verified shelf creation, file-copy import, text preview, a separate floating shelf, and the Hyper Key settings page. Test artifacts were removed afterward. Hyper Key was left off because the Mac already had a Caps Lock mapping.

The Hyper native test parses fixtures only; it does not remap keys or synthesize input. Physical-key testing should cover taps, held chords, repeat presses, releasing Caps Lock before the other key, disabling while held, app quit, and coexistence with Shortcut Detective.

### Compact floating Shelf and settings

Floating Shelf is now a dedicated `FloatingShelf` surface rather than a small launcher. It uses the Swift Shelf's 300-point width, stack/list switch, thumbnail pile, latest-three summary, copy/reference dots, count/size footer, hide control, and Clear confirmation. The pile supports dragging all files; list rows support dragging individual files. The macOS window uses Tauri's native HUD vibrancy with the active theme's window radius. Other platforms retain the themed translucent surface without claiming equivalent macOS material rendering.

Settings → Shelf lists shelves, creates/shows them, and persists Enable the shelf, Show while Shift-dragging, and Remove items after dragging them out. Disabling closes floating windows and blocks Shelf mutations without deleting contents. Existing libraries default to enabled, with both drag preferences off. Help is available through info popovers.

macOS Shift-drag uses the same content-drag check as Swift: the system drag pasteboard must change while Shift and the mouse button are held, and drags starting in Tooki are ignored. A temporary shelf opens near the pointer without focusing it. Cancelled/unused temporary shelves are discarded; receipt of a native drop protects asynchronous file imports. The OS adapter lives in `src-tauri/src/platform/shelf`. Windows/Linux explicitly report this capability unavailable, while manually opened shelves still receive file drops.

Both Shelf surfaces share `dragShelfItems`. Only a native successful-drop callback removes the snapshot of dragged entries when the preference is on. Cancelled drags keep entries. Owned copies enter a persistent retirement queue for 60 seconds, with cleanup every 30 seconds; original references are never deleted. Files still referenced by another shelf are retained. Consumers that need permanent access to a linked file should leave automatic removal off.

Floating positions are saved per shelf, debounced, and restored relative to the monitor work area. Missing displays fall back to the primary monitor and coordinates are clamped on-screen. Launcher placement is unaffected.

The official Tauri deep-link and single-instance plugins handle `tooki-preview://shelf/new`, `/show`, `/hide`, `/toggle`, `/add?path=...`, and `/clear`. `shelf=` accepts an id or unique name; `mode=copy` imports owned copies; repeated `path=` values add multiple files. Paths/names must be URL-encoded. Unknown commands and relative paths are rejected. Clear links require confirmation. The separate prototype scheme avoids taking over Swift Tooki's `tooki://` association. Scheme registration occurs when the bundled app is installed; a raw `cargo run` binary is insufficient on macOS. See [Tauri deep links](https://v2.tauri.app/plugin/deep-linking/).

Shelf tests cover legacy settings, drag cancellation, snapshot-only removal, delayed cleanup across restart, persistence failures, file ownership safety, changed display bounds, and link validation. Native behavior on Windows/Linux still requires testing on those operating systems.

The searchable Shelf Manager remains unchanged as the full management surface. The compact surface uses native context menus and shared theme colors. The manager retains the shared searchable ActionsMenu. Native window creation is isolated in `src-tauri/src/shelf/window.rs`.

### Swift Shelf behavior port, November 16

The compact Shelf now has native three-dot and item context menus, file icons/thumbnail stacks, modifier-click and Shift-arrow selection, item details with original/current path copying, actual file renaming, Quick Look, Open With, clipboard content ingestion, Option-delete, Escape stepping/hold behavior, and per-shelf/Clear All controls in Settings. Large file copies run outside the shared library lock and report progress. Unix folder copies preserve symbolic links without following them.

On macOS, Tauri/Wry owns drag destination dispatch. File drops select original-reference or owned-copy mode by the half of the window under the pointer. Text, URL and image drops use the AppKit drag pasteboard. Webview navigation is restricted to the application origin. The attempted native wrapper was removed because WebKit consumed drops before the wrapper received them. Both file-drop halves were confirmed in the running packaged build. Wry 0.57 sends AppKit-point drag coordinates inside a `PhysicalPosition` wrapper, so the macOS comparison converts the window width to points; revisit this when upgrading Wry.

Quick Look uses a shared macOS controller in `src-tauri/native/preview.m`. Previews stay above floating shelves and retain an originating window and view context. Up/Down is routed only to that view; Shelf, Clipboard and conversion review update the open preview as selection changes. Selection updates never reopen a dismissed preview. Escape, Space and Command-Y close it, and hiding or closing its owning shelf closes the preview too. Run `sh scripts/test-preview-native.sh` from `prototypes/desktop` for native ownership and navigation checks. Other platforms retain their existing preview capability gates.

Image conversion supports JPEG, PNG and HEIF, size presets, metadata preservation, partial-batch error reporting, preview review, Quick Look, Open With and reloading edited previews, saving additional owned copies, or explicitly replacing sources. Source hashes detect external edits. Replacement records are journaled before files change, with rollback on failed saves and recovery at startup. Recovery preserves unexpected external changes and reports the location of original backups instead of overwriting them.

Verification includes Svelte/TypeScript checks, frontend tests, Rust storage/selection/ownership tests, image conversion source preservation and rollback, interrupted replacement recovery, and preserving external files through copied symbolic links. UI review confirmed the compact native menu and file thumbnail.

Remaining differences from the Swift implementation: the Tauri floating window is not yet a nonactivating `NSPanel`; its resize/transition choreography and hidden-shelf HUD differ. Windows/Linux native integrations are capability-gated and have not been verified on physical hosts. Do not describe this prototype as complete one-to-one Swift parity.

## Notes

Notes opens an independent, resizable window from **Open Notes** or **New Note** in Root Search. Its position and size are separate from the launcher and restored within the current display work area. The shared `FloatingSurface` and `WindowControlGroup` components give Notes and Shelf the same material, focus outline and compact controls. macOS uses the native HUD material; other platforms use the themed surface. The resize grip uses Tauri's native resize operation.

The editor is loaded on demand and uses the MIT-licensed Tiptap core, StarterKit and task-list extensions. It supports headings, bold/italic, links, lists, checklists, quotes, code, undo/redo and find within a note. Actions reuse `PopupSurface` and `ActionsMenu`; the note browser and all panel filters reuse `FilterPopup` for search, selection, keyboard navigation, bounded scrolling and dismissal. The note browser opens below its header control, marks the current note, and keeps Trash restoration in Actions. Command shortcuts on macOS use Control on Windows/Linux: N creates, D duplicates, P browses, Shift-P pins, K opens Actions, F finds, and W saves and hides the window.

Desktop notes live in `notes/notes.sqlite3` under the prototype app-data directory. SQLite WAL transactions store structured documents and an FTS5 index of their plain text. Writes are serialized per note and use revision checks. A local recovery journal protects edits pending an IPC save; conflicting drafts are recovered as separate notes. Closing or switching waits for saves, and failures keep the draft and surface an error. Trash is reversible and is not automatically purged. Browser-only development uses a separate local-storage library.

Root Search has one Notes command; note-title and content search lives inside Notes. Actions provide pinning, duplication, plain-text/HTML copying, text/HTML/JSON export through a native Save dialog, and `tooki-preview://notes/<id>` links. Deep links only open existing active notes, and scheme registration requires a bundled app. Sync, AI, image attachments and permanent Trash removal are outside this first version.

Focused checks: `bun test src/features/notes` and `cargo test --manifest-path src-tauri/Cargo.toml notes::`. Windows/Linux use the same storage/editor code, but their native window behavior still needs verification on those systems.

## Shared inputs and corner scale

`TextInput` owns the common text-input reset and focus treatment. Search headers, filter/action popups, activity logs, Settings, and Notes compose it within their existing containers. `RenameInput` adds a draft transaction shared by Notes and floating Shelf titles: Enter, blur or an outside click commits once; Escape cancels; composition keystrokes do not submit. It uses one quiet focus border.

Set `tokens.cornerRadius` in the theme JSON to control the corner scale (0–24 points). `src/lib/themes/radii.ts` derives control, row, card and window sizes. Graphite and Porcelain currently use 18. Existing themes without this optional token retain their `shellRadius` and `rowRadius`; explicit component radius overrides still win. Circular controls and OS-owned titlebar decorations retain their shape. Floating Shelf and Notes synchronize the native macOS material radius when the active theme changes.

Hyper Key now reports saved `enabled` intent separately from the native hook's `active` status. Startup/permission failures preserve the saved preference and expose their error with Retry. Status refreshes when Settings regains focus; loading no longer briefly presents an off toggle. Retry reapplies the saved choice without installing helpers or changing permissions. Linux's optional helper remains independently managed.

## Utility window ordering and tool settings

Notes and Shelf use normal window ordering by default. Their explicit Keep on Top actions use the shared `FloatingSurface` native adapter. Notes persists this choice in its Settings page alongside formatting-toolbar visibility; Shelf's choice lasts for the current floating window. Pin Note still controls note-list ordering only. Shelf drag targets are temporarily raised; the temporary shelf returns to normal ordering when the drag finishes.

Command/Control-comma from Notes opens Notes Settings, and from Clipboard opens Clipboard Settings. Opening Notes successfully from Root Search hides the launcher. The shared launcher footer displays the existing Tooki app icon.

On macOS, explicitly enabling Hyper Key requests Accessibility permission using the system prompt. Blocked status includes Open Accessibility Settings. Returning to the Hyper Key page after granting access retries the saved enabled preference. Startup and read-only status checks never prompt. Permission is granted manually in System Settings; Tooki cannot grant it itself.

Appearance includes a visual theme editor with window-local live preview. Cancel discards the draft; Save persists and selects the theme. Built-in presets produce a custom copy, while imported themes update in place. Global colors, corner radius, font size and spacing controls retain explicit component overrides unless the user clears those overrides.


## Application search

Root Search combines one command per available tool with a cached application catalog. Matching follows Swift’s exact, prefix, word-prefix, initials, substring and subsequence tiers, ignoring case and accents. The shared result rows show application icons on macOS and a generic application icon on Windows/Linux. The All / Applications / Commands filter uses the shared filter popup.

Discovery refreshes on startup and launcher opening, outside the UI thread. macOS scans the same application folders as Swift, without descending into bundles; Windows uses Get-StartApps; Linux observes XDG desktop-entry precedence and visibility. Launch requests must match an indexed ID. Native launchers handle app arguments: macOS open, Windows AppsFolder, Linux gio (required on Linux). Windows and Linux native execution still needs verification on their respective systems.

Application Actions reuse `ActionsMenu` and the shared `ShortcutRecorder`: Open, reveal, copy location, favorite, alias, global launch shortcut, Settings and uninstall. Favorites appear first for empty searches; exact aliases outrank title matches. Preferences are stored in `application-preferences.json` in the app config directory. Shortcut registration happens on startup, avoids Tooki conflicts, and retains the previous assignment if replacement fails. Recording suppresses launcher/application shortcuts until the recording ends.

macOS uninstall asks for confirmation and moves only an eligible application bundle to Trash. System applications, the running Tooki bundle and running target applications are excluded; documents and settings remain untouched. Windows opens Installed Apps, while Linux opens GNOME Software or Discover when present. Windows catalog entries use AppsFolder locations, so their copy action is labeled Copy App Location. Send Feedback remains omitted until a destination is configured.

The root footer's Tooki menu uses a separate `app-menu` webview. `PopupWindow` hosts the unchanged shared `AppMenu` / `PopupSurface` / `ActionsMenu` content. The parent launcher retains its compact or expanded size and query. The menu anchors above the footer button when space permits, otherwise below, clamped to the display work area. Escape dismisses and restores launcher focus; blur dismisses without stealing focus. Moving/resizing the launcher also dismisses the popup.

### General and Applications settings

General now exposes launch at login through the official Tauri autostart plugin and persistent visibility of Tooki’s own menu bar/tray icon. Login starts use `--autostart` and keep Root Search hidden. The tray menu provides Open Tooki, Settings and Quit. Login state is read from the operating system; tray visibility is stored in `general-settings.json`. Linux tray availability depends on the desktop’s status notifier support.

Applications settings shares the catalog and `ApplicationActions` with Root Search, including favorites, aliases and launch shortcuts. Native preference change events synchronize both windows. Refresh runs discovery in the background and reports progress without blocking search.

The shared `PanelFilterMenu` includes the label, chevron and shortcut keycaps inside a single button, with aligned content and one hover/pressed target across Root Search, Clipboard, Shelf and activity logs.

Compact Root Search omits the filter control and its shortcut listener; typing or Show More reveals it with the results. Filter popups use a dedicated anchored native window on desktop, shared by every `FilterPopup` consumer (including asynchronous Notes browsing). `FilterPopupContent` remains the single UI implementation, also used inline by the browser preview. Queries and selections are scoped to an opening session and its owning window. Blur, parent movement/resizing/closing and launcher dismissal close the native popup; selection and Escape restore owner focus. App and filter popups share screen-edge positioning without resizing Root Search.

Launcher reopening uses a preparation handshake: reset Root Search and await its themed size while hidden, then acknowledge the current native presentation request. The global shortcut cancels a pending reopen; superseded acknowledgements cannot show the window. Tray and second-instance activation reuse this path. No timing delay is used.

On macOS, launcher resizing uses one AppKit frame update that preserves the current top-left corner. The resize command completes only after that main-thread update, avoiding both position drift and the early completion of Tao’s queued `setContentSize` path. Other platforms preserve the current outer position around the Tauri resize.

Filter popup density is shared across every consumer: 200 px content width, 30 px search field and 26 px rows. The native host measures rendered content before showing, fits its height to the current results (250 px content maximum), and repositions below the trigger or above when screen space is limited. Long lists scroll; short lists do not retain blank space.

Actions menus share compact 28 px rows, 15 px icons, 12 px labels and a 32 px search field. The list caps at seven rows plus padding; only the list scrolls. Short inline menus size naturally, and the native Tooki menu measures the same shared content when its actions are filtered.

### Tool command assignments and Shortcuts

`features/shortcuts/commands.json` is the shared tool command registry, consumed by the frontend and native `tool_commands` dispatcher. `ToolCommands` and `ShortcutsSettings` reuse `AssignmentRow`, the existing shortcut recorder, keycaps, dialogs and settings rows. Customized shows aliases and newly assigned or changed shortcuts; All shortcuts exposes available tool commands, the launcher and saved application assignments. Fixed Open Settings is labeled as a built-in, window-focused shortcut.

Tool command IDs use a `command:` namespace in the existing application assignment store, retaining atomic persistence, conflict protection and cross-window change events. The launcher retains its existing storage and broadcasts changes to the same settings views. Shelf disable/enable unregisters/re-registers its saved command shortcuts without deleting assignments. Notes and Clipboard currently have no tool-wide enable switch.

Root Search retains one primary command per tool. Secondary actions become searchable only through an exact assigned alias. Clipboard and Shelf Manager global commands use the existing launcher preparation handshake to select the destination and resize before presentation. Notes browsing uses a pending request consumed after the Notes editor is ready.

Tool-window shortcuts share the focus policy in `window_toggle.rs`: an already
active, visible, non-minimized target hides; otherwise the command opens or
focuses its target. Notes retains its save-before-hide close event. Shelf Manager
and Clipboard report their current view from the launcher so switching tools in
the shared window does not accidentally hide it. Owned filter popups count as
focus within their tool. A repeated Shelf Manager or Clipboard shortcut also
cancels its pending presentation, preventing a late open after a rapid toggle.

System Actions reuses the tool command registry, AssignmentRow, Shortcuts page,
SearchHeader, grouped result rows and bottom action bar. Its single Root Search
entry opens Sleep, Empty Trash and Eject Disk. The macOS adapter uses pmset for
sleep, Finder automation for confirmed Trash deletion, and mounted-volume
metadata plus ordinary diskutil ejection. It never force-unmounts busy disks.
Volume IDs include the volume UUID and mount location, and are revalidated before
execution. Empty Trash confirmation is enforced in the backend, including when
invoked by a global shortcut. Finder denial offers Automation settings; the
bundle includes its usage description and Apple Events entitlement.

Commands can declare a `capability` in `commands.json`. The backend reports
availability, refuses unsupported execution, and skips shortcut registration;
shared assignment rows retain saved values and explain why the action is
unavailable. Root Search and exact-alias results omit unsupported actions.
The initial System Actions adapter supports macOS only. Windows/Linux show
unavailable rows until their adapters are implemented. No connected disks is an
empty result, not an unsupported capability. Native tests enumerate volumes
read-only; sleep, real Trash deletion and real ejection are not run by tests.

Themes now include `searchFontSize` (14–28 px) with a separate Search text size
control in Edit theme. All shared SearchHeader consumers, including the live
preview, use the same CSS variable. Imported legacy themes default to 20 px.
