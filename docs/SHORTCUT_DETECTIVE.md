# Shortcut Detective and Activity Log

Shortcut Detective lives in Settings. Choose Run shortcut to observe a real shortcut, or Look up shortcut to inspect known assignments. Ordinary typing is ignored. Listening stops when leaving the page, closing Settings, or after five minutes.

## Platform support

| Platform | Global observation | Lookup | Limits |
| --- | --- | --- | --- |
| macOS | Accessibility event taps and delivery comparison | Tooki, system shortcuts, simple skhd bindings and accessible app menus | Missing delivery suggests interception but does not identify an owner. Secure input and earlier interceptors can hide presses. |
| Windows | Low-level keyboard hook | Tooki launcher assignment | Secure desktops, elevated applications and earlier hooks can limit visibility. Does not claim a consuming app's identity. |
| Linux X11 | X RECORD | Tooki and supported GNOME/KDE settings | Observation only; cannot block global presses. Requires X11 recording libraries. |
| Linux Wayland | Unavailable | Focused shortcut entry and supported desktop settings | Compositor restrictions prevent arbitrary global observation. |

The macOS implementation has been exercised locally. Windows and Linux backends have been cross-compiled; live checks on those platforms remain necessary.

## Shared ActivityLog

`src/components/activity-log/ActivityLog.svelte` accepts entries, column definitions, category filters, a title, export filename and clear callback. Entries have stable IDs, timestamps, cells and optional detail fields. Feature adapters translate their own results into this generic shape.

- Compact rows scroll within a bounded viewport. TanStack Virtual renders the visible range.
- Search matches cells and details. Category filters combine with search.
- Click a row to expand details. Arrow keys, Page Up/Down, Home/End and Command/Control + arrows navigate results.
- Follow latest scrolls to incoming results. Navigating or scrolling upward pauses following.
- Copy produces readable text; Export saves JSON through a native save dialog. Both include all matching entries, including offscreen rows.
- Clear removes the current in-memory history. History survives stopping and restarting listening, but is not persisted after quitting.
- Native events append one result at a time rather than retransmitting the entire history. Status responses replace the snapshot; revision numbers reject stale responses.

The component inherits shared theme tokens. Optional `activityLog` overrides are `background`, `hover`, `selected`, `text` and `radius`. Other tools should reuse this component and provide their own columns and adapter.

## Verification

From `prototypes/desktop`:

```sh
bun run check
bun test
cargo test --manifest-path src-tauri/Cargo.toml
make test-detective
make test-detective-native
```

The component gallery at `/?gallery=1#activity-log` uses 5,000 synthetic entries without starting monitoring or reading real clipboard history. It includes an append control for testing Follow latest.

Design sources: `design/tooki-design-system.fig` inside this prototype and the repository's `design/ui-component-names-sketch.fig`.
