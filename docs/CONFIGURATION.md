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
  },
  "shelf": {
    "enabled": true,               // false also makes tooki://shelf links beep
    "shiftDragOpens": true,        // show the shelf while Shift-dragging
    "removeAfterDragOut": true
  },
  "updates": {
    "checkAutomatically": true     // check GitHub on launch and once a day
  }
}
```

Keys for bindings are letters, digits, punctuation, or `space`, `return`, `tab`, `escape`, `left`, `right`, `up` and `down`.

**Actions:** `search`, `clipboard`, `shelf.toggle`, `keepAwake.toggle`, `menuBar.toggle`, `menuBar.search`, `settings`, `open:<bundle id or app path>` (opens the app, or hides it when it's already in front).

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

## Shelf

The shelf is a floating spot to collect files while you move between folders and apps. Hold **Shift** while dragging anything to make it appear next to the pointer, then drop onto it. You can also open it from the menu bar menu, from search, or by binding the `shelf.toggle` action to a shortcut.

It holds files and folders. Dropped or pasted text, links and images are saved as files (`.txt`, `.webloc`, `.png`) so you can drag them into any app. Text files are named after the first words, letters and digits only, up to 30 characters. Items stay on the shelf after Tooki restarts.

You can have several shelves, each in its own floating panel. Every Shift-drag opens a fresh shelf next to the pointer (dropping on a shelf that's already showing adds to that one instead). Shelves are named Shelf 1, Shelf 2 and so on; rename one with **Rename** in its ⋯ menu. Drag a shelf by its name or any empty part of its header or footer (the pointer turns into a hand). A focused shelf has a soft blue glow. The `shelf.toggle` shortcut hides every shelf, or shows them all, or opens a new one when there are none. The menu bar menu and the Shelf page list every shelf, with New Shelf and Clear All.

Each file on the shelf is one of two kinds, shown by a badge on its icon. One shelf can mix both, even for the same file:

| | Link to original (orange arrow) | Copy (green pages) |
| --- | --- | --- |
| Where the file lives | Where it already is | Tooki's own copy in `~/Library/Application Support/Tooki/shelf-items`, so it survives reboots |
| Dragging it out | Uses the real file: dropping it on a folder on the same disk **moves** it | Hands over the copy; the original never moves |
| Removing it from the shelf | Leaves the file alone | Deletes Tooki's copy (a minute later after a drag out, so uploads can finish) |

When you drag files onto the shelf, it splits in two: drop on the left half to **link to the original**, or on the right half to **make a copy**. Pasting with ⌘V adds originals. Dropped text, links and images are always copies. Big folders take a moment to copy; the row shows a green progress bar until it's ready.

- Folded, the shelf shows a stack next to the three newest names, with an orange or green dot for originals and copies. Drag the stack to take every item along. **Show N items** under it (or Return, ↓) opens the list. The Stack | List switch in the header does the same. The shelf keeps its width and the icons glide into their rows.
- The header's **–** button hides the shelf and keeps its items; a short "Shelf hidden" note shows where it was. Hold ⌥ and it turns into a red delete button. The ⋯ menu has Rename, Show All in Finder, Copy All Paths, Clear and Delete Shelf. When the shelf holds Tooki's copies, Delete and Clear turn red and ask "Delete?" or "Clear?" right on the button: click again or press Return to go ahead, or press Esc, move away or wait to cancel. Originals are never touched. Rename allows up to 20 characters. Images show a small preview instead of their icon.
- The list shows one row per item, with its size (or Folder, or Link) on the right. Hover a row and click ⓘ (or press →) to slide over to its details: mode, size, current path and original path. ← or **All items** goes back. Click to select, ⌘ or ⇧ click to select more, and drag to take the selection. Double-click opens an item.
- Right-click an item (or the selection, or the stack for everything) for Quick Look, Open, Open With, Show in Finder, Copy, Copy Path and Remove from Shelf. Copies also offer Show Original in Finder and Copy Original Path. **Rename** renames the file on disk: the real file for an original, Tooki's file for a copy.
- Items you drag out leave the shelf (turn off `removeAfterDragOut` to keep them), and the shelf closes for good once it's empty (turn off `closeWhenEmpty` to keep it open). **Clear** always keeps the shelf open. Hiding an empty shelf also closes it. For originals, Finder decides between copy and move: dragging to a folder on the same disk **moves** the file. Use a copy when that matters.

| Key (while the shelf is focused) | Action |
| --- | --- |
| ⌘V | Add what's on the clipboard |
| ⌘A | Select all |
| ⌘N | New shelf |
| Return or ↓ | Unfold a folded shelf (↓ also selects the first item) |
| Space | Quick Look the selection (or every item when nothing is selected) |
| Delete | Remove the selection from the shelf (the files themselves are kept) |
| ↑ ↓ | Move the selection in the list (⇧ to extend). Works on the details page and while Quick Look is open too, and they follow |
| → ← | Show the selected item's details, and go back to the list |
| Esc | Step back: from details to the list, then fold the list, then hide the shelf |
| Hold Esc | Delete the shelf. It shrinks and turns red while held; let go early to cancel. If the shelf holds copies, the – button turns into "Delete?" to confirm |

`config.json` options under `shelf`: `enabled`, `shiftDragOpens`, `removeAfterDragOut` and `closeWhenEmpty` (all `true` by default).

### URL commands

Other apps and scripts can control Tooki with `tooki://` links. Use `open -g` to run them without bringing Tooki forward.

| Link | Action |
| --- | --- |
| `tooki://shelf/add?path=/a&path=/b` | Add files or folders as originals to the most recently used shelf and show it. Paths must be percent-encoded (a space is `%20`); `~` is expanded |
| `tooki://shelf/add?path=/a&mode=copy` | Add Tooki's own copies instead, so the originals never move |
| `tooki://shelf/add?path=/a&shelf=Work` | Add to the shelf with this name or id. A name that doesn't exist yet makes a new shelf with that name; `shelf=new` always makes a new one |
| `tooki://shelf/new` | Open a new empty shelf |
| `tooki://shelf/show`, `/hide`, `/toggle` | Show or hide every shelf, or one with `?shelf=<name or id>` |
| `tooki://shelf/clear` | Clear and close every shelf without asking, or one with `?shelf=<name or id>` |
| `tooki://run/<action>` | Run an action from the list above, such as `tooki://run/clipboard`. `open:` is not allowed from links |

Tooki beeps when a link isn't recognized or none of the paths exist.

Save this script as an executable file on your `PATH` (for example `~/.local/bin/tooki-shelf`, then `chmod +x` it) to add files from the terminal, fzf or yazi. Pass `-c` to add copies and `-s <name, id or new>` to pick a shelf. The same script can be copied from General › URL Scheme.

```sh
#!/bin/sh
# Adds files and folders to a Tooki shelf.
# Usage: tooki-shelf [-c] [-s <shelf>] <paths…>
#   -c          add copies, so the originals never move
#   -s <shelf>  a shelf name or id, or "new" (default: the most recently used shelf)
#        tooki-shelf list   prints id, name and item count for each shelf
tooki="${TOOKI_BIN:-/Applications/Tooki.app/Contents/MacOS/Tooki}"
if [ "$1" = "list" ]; then exec "$tooki" shelf list; fi
encode() { printf '%s' "$1" | perl -pe 's/([^A-Za-z0-9\/._~-])/sprintf("%%%02X", ord($1))/ge'; }
mode=original
shelf=""
while getopts "cs:" option; do
  case $option in
    c) mode=copy ;;
    s) shelf="&shelf=$(encode "$OPTARG")" ;;
    *) exit 64 ;;
  esac
done
shift $((OPTIND - 1))
query=""
for path in "$@"; do
  path=$(cd "$(dirname -- "$path")" && printf '%s/%s' "$PWD" "$(basename -- "$path")")
  query="$query&path=$(encode "$path")"
done
open -g "tooki://shelf/add?${query#&}&mode=$mode$shelf"
```

`tooki-shelf list` runs `Tooki shelf list`, which prints one line per shelf (id, name and item count, separated by tabs), most recently used first. It reads what Tooki saved, so it works even when Tooki isn't running. Set `TOOKI_BIN` if Tooki isn't in `/Applications`.

With fzf, pick files with Tab and shelve them:

```sh
fzf -m --print0 | xargs -0 tooki-shelf
```

In yazi, use a plugin that adds the selection (or the hovered file). When shelves are open it asks which one: `1` to `9` for a shelf, `n` for a new one. Save it as `~/.config/yazi/plugins/tooki-shelf.yazi/main.lua`:

```lua
--- Adds the selected files and folders (or the hovered one) to the Tooki shelf.
--- `plugin tooki-shelf -- copy` adds Tooki's own copies, so the originals never move.
--- Without an argument it links to the originals.
--- When shelves are open, a picker asks which one: 1-9 for an open shelf, n for a new one.

local selected_paths = ya.sync(function()
	local paths = {}
	for _, url in pairs(cx.active.selected) do
		paths[#paths + 1] = tostring(url)
	end
	if #paths == 0 and cx.active.current.hovered then
		paths[1] = tostring(cx.active.current.hovered.url)
	end
	return paths
end)

local function percent_encode(text)
	return (text:gsub("[^%w/._~-]", function(char)
		return string.format("%%%02X", char:byte())
	end))
end

local tooki = os.getenv("TOOKI_BIN") or "/Applications/Tooki.app/Contents/MacOS/Tooki"

--- Open shelves from `Tooki shelf list`, most recently used first.
local function open_shelves()
	local output = Command(tooki):arg("shelf"):arg("list"):output()
	local shelves = {}
	if not output or not output.status.success then
		return shelves
	end
	for line in output.stdout:gmatch("[^\n]+") do
		local id, name, count = line:match("^([^\t]+)\t([^\t]*)\t(%d+)$")
		if id then
			shelves[#shelves + 1] = { id = id, name = name, count = tonumber(count) }
		end
	end
	return shelves
end

--- Returns the shelf query (`shelf=<id>` or `shelf=new`), "" with no shelves open, or nil when cancelled.
local function pick_shelf()
	local shelves = open_shelves()
	if #shelves == 0 then
		return ""
	end
	local cands = {}
	for i = 1, math.min(#shelves, 9) do
		local shelf = shelves[i]
		local items = shelf.count == 1 and "1 item" or string.format("%d items", shelf.count)
		cands[i] = { on = tostring(i), desc = string.format("%s (%s)", shelf.name, items) }
	end
	cands[#cands + 1] = { on = "n", desc = "New shelf" }
	local choice = ya.which({ cands = cands })
	if not choice then
		return nil
	elseif choice == #cands then
		return "shelf=new"
	end
	return "shelf=" .. shelves[choice].id
end

local function notify(content, level)
	ya.notify({ title = "Tooki Shelf", content = content, timeout = 3, level = level or "info" })
end

return {
	entry = function(_, job)
		local as_copy = job.args[1] == "copy"
		local paths = selected_paths()
		if #paths == 0 then
			return notify("Nothing to add", "warn")
		end

		local shelf = pick_shelf()
		if shelf == nil then
			return
		end

		local query = {}
		for _, path in ipairs(paths) do
			query[#query + 1] = "path=" .. percent_encode(path)
		end
		query[#query + 1] = "mode=" .. (as_copy and "copy" or "original")
		if shelf ~= "" then
			query[#query + 1] = shelf
		end
		local link = "tooki://shelf/add?" .. table.concat(query, "&")

		local status, err = Command("open"):arg("-g"):arg(link):status()
		if not status or not status.success then
			return notify("Couldn't reach Tooki: " .. tostring(err or status.code), "error")
		end
		local count = #paths == 1 and "1 item" or string.format("%d items", #paths)
		notify(as_copy and ("Copied " .. count) or ("Added " .. count .. " as originals"))
	end,
}
```

Then add keys to `keymap.toml`. `T s` adds copies (the safe choice) and `T S` adds the originals:

```toml
[[mgr.prepend_keymap]]
on   = ["T", "s"]
run  = "plugin tooki-shelf -- copy"
desc = "Add a copy of the selection to a Tooki shelf"

[[mgr.prepend_keymap]]
on   = ["T", "S"]
run  = "plugin tooki-shelf -- original"
desc = "Add the selected originals to a Tooki shelf"
```

## Menu bar organizer

Tooki adds a toggle icon and a thin separator to the menu bar. Hold ⌘ and drag icons to the **left of the separator** to hide them. Click the toggle to show them. macOS remembers icon positions itself, so the arrangement is not part of `config.json`.

Press **Hyper + M** to search every menu bar item, shown or hidden, including Apple's (Clock, Wi‑Fi, Battery). Press Return to click the selected item. If it is hidden, Tooki reveals the hidden icons, clicks it, and hides them again once its menu closes. A few apps ignore clicks made through Accessibility; Tooki beeps when an item refuses.

## Updates

Release builds check GitHub for a new version when Tooki starts and once a day. When one is found, an **Update** badge appears on the Tooki card at the bottom of the sidebar. Open **About** to install it, skip that version, or check by hand. Installing downloads the DMG, makes sure it is signed with the same certificate as the running app, replaces Tooki and restarts it. Skipping only hides the badge; the update stays available in About. Dev builds never check.

## Known limitations

- **Other key remaps:** Hyper uses `hidutil`. When Tooki quits, it clears all `hidutil` key mappings, including ones you set yourself.
- **Closed lid:** Keep Awake can't stop sleep when the lid is closed unless an external display is connected. Display mode also prevents the screen from auto-locking.
- **Copied images are saved to disk:** Screenshots can contain sensitive data. Set `maxImages` to 0 to skip images, or `persistHistory` to false to delete them when Tooki restarts.
- **Secure input:** Snippet keywords don't expand in password fields, or while an app has Secure Input enabled.
- **Other menu bar managers:** Don't run Tooki's organizer alongside Bartender, Ice or Thaw. They use the same technique and will fight over the menu bar. Turn off `menuBar.enabled` if you keep another one.
- **Unofficial hiding:** There is no official API for hiding other apps' icons. A future macOS update could change how this behaves.
