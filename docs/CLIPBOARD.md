# Clipboard Manager

The desktop prototype owns its history independently of Swift Tooki. It does not import, modify, or delete the Swift app's clipboard data.

## Architecture

- `src-tauri/src/clipboard/`: Rust service, SQLite storage, settings, and ID-based commands.
- `src-tauri/native/clipboard.m`: macOS pasteboard, Apple Vision, Quick Look, application discovery, and paste-to-previous-app bridge.
- `src/features/clipboard/`: Svelte list/detail screen, settings, and typed command client.
- Shared search, rows, grouping, filters, actions, footer, keycaps, and settings controls continue to use the existing theme system.

History is in the prototype's application support directory under `clipboard/history.sqlite3`. PNG images live beside it; FTS5 indexes text, paths, source apps, and recognized text. OCR stays on-device and runs separately from capture. No AI service or network OCR is used.

## Behavior

Capture observes pasteboard changes every 500 ms. It supports text, links, hex colors, images, and file URLs. Rich HTML/RTF accompanies text when available. Duplicate content retains its identity and pinned state, increments its copy count, and moves to the most recently copied position.

Pinned items survive ordinary retention, item limits, and clearing history unless explicitly included. Default limits are 200 ordinary items and 50 images. Settings also provide pause, retention days, session-only history, OCR, and excluded application bundle identifiers. Concealed, transient, and automatically generated clipboard types are skipped.

The list fetches 100 items per page, with Previous/Next controls. Arrow keys and Page Up/Down cross page boundaries; Command-Up/Down go to the first/last item. Search is literal, including punctuation, and uses a 120 ms input debounce. Selection restoration uses item identity so newly copied items do not move the remembered selection to a different clip.

| Action | Shortcut |
|---|---|
| Copy original content | Return |
| Paste into previous app | Command-Return |
| Quick Look | Command-Y |
| Open With | Command-O |
| Pin or unpin | Shift-Command-P |
| Delete item | Control-X |
| Filter types | Command-P |
| Actions | Command-K |
| Root Search | Command-Escape |

Drag the footer's Drag button into another app to export a file, image, or text file. Copy Plain Text, Copy File Paths, Copy Recognized Text, and OCR retry are in Actions where applicable. Missing original files report an error rather than silently copying invalid paths.

## Boundaries

Native integration currently targets macOS. Other platforms return an explicit unsupported error; they need their own native adapters. Paste requires macOS Accessibility permission. Quick Look and Open With use system applications.

Text and rich formats are limited to 4 MB each; images to 32 MB and 100 million pixels. Original files are referenced, not duplicated. Session-only text metadata stays in memory, while images require local temporary storage. Temporary exports and session images are removed on normal exit; crash leftovers are removed on the next launch. History is not encrypted by the app.

Shelf integration remains deferred until Shelf is implemented in this prototype. Quick Look opens native previews but does not synchronize arrow navigation back into the launcher list. Files have path/metadata previews; use Quick Look for their native contents.

## Verification

From `prototypes/desktop`:

- `bun run check`, `bun test`, `bun run build`
- `cargo test --manifest-path src-tauri/Cargo.toml -- --nocapture`
- `make test-clipboard-native` on macOS

The native test uses a separate named pasteboard and synthetic image, never the user's clipboard history. Rust tests use temporary databases and include 5,000-item paging and indexed search. Native UI checks cover persistence across restart, text/image capture, OCR search, pinning, Quick Look, Open With, and Clipboard settings. The paste permission guard was verified; successful cross-app paste requires granting Accessibility. External drag/drop still needs a manual check in a destination app. Source-app attribution is best effort, based on the foreground app when a clipboard change is observed.
