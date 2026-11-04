# Tooki

Tooki ("ToolKit") is a small native macOS menu bar app that replaces several third-party utilities with one tool you build and sign yourself.

| Module | Replaces | What it does |
|---|---|---|
| Hyper Key | Karabiner, Raycast | Caps Lock becomes ⌃⌥⇧⌘. A quick tap still toggles Caps Lock. Bind Hyper + key to actions. |
| Snippets | Raycast snippets | Type a keyword (`;date`) to expand it, or pick a snippet from the search panel. Supports dynamic placeholders. |
| Clipboard | Raycast clipboard history | Searchable history of text, links, colours, images and files, with a preview and pinning. Text inside images is searchable too. Skips password managers and concealed items. |
| Menu Bar | Bartender, Hidden Bar | Hides menu bar icons behind a toggle. |
| Keep Awake | Amphetamine, KeepingYouAwake | Prevents idle sleep for a set time, while certain apps run, or only on power. |

## Install

Download `Tooki.dmg` from the [latest release](https://github.com/tahsinature/tooki/releases/latest), open it and drag Tooki to Applications. Or use Homebrew:

```sh
brew install --cask tahsinature/tap/tooki
```

Tooki is not notarized by Apple. When you install from the DMG, macOS blocks the first launch: open System Settings → Privacy & Security and click **Open Anyway**. The Homebrew cask removes the quarantine flag for you. After an update, you may need to grant Accessibility again.

To upgrade with Homebrew, run `brew upgrade --cask --greedy tooki`, because the cask always points at the latest release.

## Build from source

Requires macOS 14 or later and Swift 6. Apple's Command Line Tools (`xcode-select --install`) are enough. Full Xcode is not needed.

```sh
make test      # unit tests
make app       # builds and signs build/Tooki.app
make run       # builds and opens it, replacing any running copy
make install   # copies it to /Applications
make dmg       # builds build/Tooki.dmg
make info      # builds the app and shows its size, version, and requirements
```

The app is signed with your "Apple Development" certificate when you have one. A stable signature means macOS keeps the Accessibility permission across rebuilds. Without a certificate, the Makefile signs ad hoc, and you may need to grant Accessibility again after rebuilding. Override with `make app SIGN_ID="..."`.

Use `make dmg ARCHS="arm64 x86_64"` for a universal build (needs full Xcode).

## Releasing

Push a version tag, and GitHub Actions tests the code, builds a universal `Tooki.dmg` and attaches it to a new release:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

Running the Release workflow manually builds the DMG as a workflow artifact without publishing anything. The Homebrew cask lives in [tahsinature/homebrew-tap](https://github.com/tahsinature/homebrew-tap) (source: `packaging/tooki.rb`) and needs no change per release.

## Permissions

Tooki needs **Accessibility** (System Settings → Privacy & Security → Accessibility) for the Hyper key, snippet keywords and pasting. Until it is granted, Caps Lock is left alone and those features stay off. Tooki picks up the grant automatically within a couple of seconds.

Grant it to the copy you actually run (for example `/Applications/Tooki.app`). Launching the binary from a terminal borrows the terminal's permission instead, which is misleading when testing.

## Configuration and dotfiles

Tooki reads two files from `~/.config/tooki/` (or `$TOOKI_CONFIG_DIR`):

- `config.json`: module settings and Hyper key bindings
- `snippets.json`: your snippets

To keep them in dotfiles, symlink the folder (or the individual files) into your dotfiles repository. Tooki writes through symlinks without replacing them, and edits made outside Tooki are picked up within 2 seconds. Missing keys fall back to defaults; invalid values are reported on the General page instead of being overwritten.

### Clipboard history

Press Hyper+V to open it. The list is on the left (Pinned first, then Most Recent) and the selected entry is previewed on the right with its source app, size and copy counts. Filter by typing, or pick a type (Text, Links, Colors, Images, Files) from the menu. Pinned entries are never removed by `maxItems`.

| Key | Action |
| --- | --- |
| ↑ ↓ (hold to repeat), Page Up/Down, Home/End | Move through the list |
| ↵ | Paste into the app you were using |
| ⌘↵ | Copy to the clipboard |
| ⌘O | Open With: search for an app to open an image, file or link with (Esc goes back) |
| ⌘P | Pin or unpin |
| ⌃X | Delete |
| ⌘K | Show all actions. Type to filter them, and the list behind stays as it was |

Clipboard history is private data and is stored separately in `~/Library/Application Support/Tooki/` (copied images go in `clipboard-images/`). Text in images is read with Apple's Vision framework on this Mac; nothing is sent anywhere.

### config.json

```jsonc
{
  "hyperKey": {
    "enabled": true,
    "bindings": [
      { "key": "s", "action": "search" },
      { "key": "v", "action": "clipboard" },
      { "key": "a", "action": "keepAwake.toggle" },
      { "key": "m", "action": "menuBar.search" },
      { "key": ",", "action": "settings" },
      { "key": "t", "action": "open:com.apple.Terminal" }
    ]
  },
  "snippets": {
    "enabled": true,
    "keywordExpansion": true       // false keeps snippets in the search panel only
  },
  "clipboard": {
    "enabled": true,
    "maxItems": 200,
    "maxImages": 50,               // images count toward maxItems; 0 turns images off
    "persistHistory": true,
    "ignoredApps": ["com.1password.1password"]
  },
  "menuBar": {
    "enabled": true,
    "startCollapsed": true,
    "autoHideSeconds": 0           // 0 = stay expanded until toggled
  },
  "keepAwake": {
    "mode": "display",             // "display" keeps the screen on, "system" lets it dim
    "defaultDurationMinutes": 0,   // 0 = until turned off
    "onlyOnPower": false,
    "activateForApps": ["us.zoom.xos"]
  }
}
```

Keys for bindings are letters, digits, punctuation, or `space`, `return`, `tab`, `escape`, `left`, `right`, `up` and `down`.

**Actions:** `search`, `clipboard`, `keepAwake.toggle`, `menuBar.toggle`, `menuBar.search`, `settings`, `open:<bundle id or app path>`.

Hyper + any unbound key is passed on as ⌃⌥⇧⌘ + key, so it also works with shortcuts in other apps.

### snippets.json

```json
[
  {
    "id": "8B1D248E-A982-4CE4-AF51-AA88B46FFB5C",
    "name": "Email reply",
    "keyword": ";thanks",
    "collection": "Work",
    "text": "Hi {argument:name},\n\nThanks for reaching out. {cursor}\n\nBest,\nMohammad"
  }
]
```

`id` is optional when you write snippets by hand. Placeholders:

| Placeholder | Result |
|---|---|
| `{date}` / `{date:yyyy-MM-dd}` | Today's date, with an optional format |
| `{time}` / `{time:HH:mm}` | The current time |
| `{clipboard}` | The current clipboard text |
| `{cursor}` | Where the cursor ends up after insertion |
| `{argument:name}` | Asks for a value before inserting |

## Menu bar organizer

Tooki adds a toggle icon and a thin separator to the menu bar. Hold ⌘ and drag icons to the **left of the separator** to hide them. Click the toggle to show them. macOS remembers icon positions itself, so the arrangement is not part of `config.json`.

Press **Hyper + M** to search every menu bar item, shown or hidden, including Apple's (Clock, Wi‑Fi, Battery). Press Return to click the selected item. If it is hidden, Tooki reveals the hidden icons, clicks it, and hides them again once its menu closes. A few apps ignore clicks made through Accessibility; Tooki beeps when an item refuses.

## Known limitations

- **Other key remaps:** Hyper uses `hidutil`. When Tooki quits, it clears all `hidutil` key mappings, including ones you set yourself.
- **Closed lid:** Keep Awake can't stop sleep when the lid is closed unless an external display is connected. Display mode also prevents the screen from auto-locking.
- **Copied images are saved to disk:** Screenshots can contain sensitive data. Set `maxImages` to 0 to skip images, or `persistHistory` to false to delete them when Tooki restarts.
- **Secure input:** Snippet keywords don't expand in password fields, or while an app has Secure Input enabled.
- **Other menu bar managers:** Don't run Tooki's organizer alongside Bartender, Ice or Thaw. They use the same technique and will fight over the menu bar. Turn off `menuBar.enabled` if you keep another one.
- **Unofficial hiding:** There is no official API for hiding other apps' icons. A future macOS update could change how this behaves.

## Project layout

```
Sources/TookiKit/     Logic without UI (config, placeholders, keyword matching). Unit tested.
Sources/Tooki/Core/   Event tap, synthetic keys, pasting, storage, panels.
Sources/Tooki/Modules One folder per module (controller + settings view).
Sources/Tooki/App/    App entry, wiring, settings window.
packaging/            Homebrew cask.
.github/workflows/    Release workflow (DMG on version tags).
```

Use `@ViewState` for view-owned state. It aliases SwiftUI's `State` property wrapper, avoiding the SwiftUI macro plugin missing from the macOS 27 Command Line Tools.

To add a tool, create a folder under `Modules/`, add its config struct to `TookiKit/Config.swift`, wire it in `AppController`, and add a page to `SettingsPage`.

## License

Copyright (C) 2026 Mohammad Tahsin

Tooki is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3. It is distributed without any warranty. See [LICENSE](LICENSE) for the full text.
