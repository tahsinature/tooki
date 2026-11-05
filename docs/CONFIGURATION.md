# Using and configuring Tooki

## Permissions

Tooki needs **Accessibility** (System Settings → Privacy & Security → Accessibility) for the Hyper key, snippet keywords and pasting. Until it is granted, Caps Lock is left alone and those features stay off. Tooki picks up the grant automatically within a couple of seconds.

Grant it to the copy you actually run (for example `/Applications/Tooki.app`). Launching the binary from a terminal borrows the terminal's permission instead, which is misleading when testing.

## Configuration and dotfiles

Tooki reads two files from `~/.config/tooki/` (or `$TOOKI_CONFIG_DIR`):

- `config.json`: module settings and Hyper key bindings
- `snippets.json`: your snippets

To keep them in dotfiles, symlink the folder (or the individual files) into your dotfiles repository. Tooki writes through symlinks without replacing them, and edits made outside Tooki are picked up within 2 seconds. Missing keys fall back to defaults; invalid values are reported on the General page instead of being overwritten.

### Clipboard history

Press Hyper+V to open it. The list is on the left (Pinned first, then Most Recent) and the selected entry is previewed on the right with its source app, size and copy counts, above the Copy, Paste, Drag and More buttons. Filter by typing, or pick a type (Text, Links, Colors, Images, Files) from the menu. Pinned entries are never removed by `maxItems`.

| Key | Action |
| --- | --- |
| ↑ ↓ (hold to repeat), Page Up/Down, Home/End | Move through the list |
| ↵ (or double-click) | Copy to the clipboard |
| ⌘↵ | Paste into the app you were using |
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
