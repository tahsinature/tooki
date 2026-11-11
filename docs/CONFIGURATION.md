# Using and configuring Tooki

## Permissions

Tooki needs **Accessibility** (System Settings → Privacy & Security → Accessibility) for the Hyper key, snippet keywords and pasting. Until it is granted, Caps Lock is left alone and those features stay off. Tooki picks up the grant automatically within a couple of seconds.

Grant it to the copy you actually run (for example `/Applications/Tooki.app`). Launching the binary from a terminal borrows the terminal's permission instead, which is misleading when testing.

## Configuration and dotfiles

Tooki reads two files from `~/.config/tooki/` (or `$TOOKI_CONFIG_DIR`):

- `config.json`: module settings and Hyper key bindings
- `snippets.json`: your snippets

To keep them in dotfiles, symlink the folder (or the individual files) into your dotfiles repository. Tooki writes through symlinks without replacing them, and edits made outside Tooki are picked up within 2 seconds. Missing keys fall back to defaults; invalid values are reported on the General page instead of being overwritten.

### Launcher

Bind the `search` action (for example `opt+space`) to open the launcher. Like Asyar, it searches apps and commands. Before you type, it lists your most-used results under **Recent**, then Applications and Commands. Snippets, clipboard history and emoji have their own panels: open them from the launcher (Search Snippets, Clipboard History, Emoji Picker) or bind their own shortcuts. A panel opened from the launcher goes back to it when you press Esc. ⌘Esc goes back to the launcher from any panel, however you opened it. Press ⌘P, or click the menu next to the search field, to show only Applications or Commands. The clipboard and snippets panels use ⌘P the same way for their type and collection menus. Typing ranks everything by how well the name matches (whole name, start, start of a word, initials such as `vsc` for Visual Studio Code, then anywhere), plus a boost for results you pick often and recently. Your picks are stored privately in `~/Library/Application Support/Tooki/launcher-history.json`.

Apps are found in `/Applications`, `/System/Applications`, `~/Applications` and their subfolders. Type a calculation such as `12 * 3` or `20% of 150` to see the answer card at the top; ↵ copies the answer.

| Key | Action |
| --- | --- |
| ↑ ↓, Page Up/Down | Move through the results |
| ↵ | Open, paste or run the selected result |
| ⌘↵ | Copy it instead |
| ⌘K | Show all actions, such as Show in Finder |
| ⌘, | Close the launcher and open Settings (or click Tooki in the bottom-left corner) |

### Snippets panel

The `snippets` action opens your snippets in their own panel, laid out like clipboard history: pinned snippets first, then the rest grouped by when you last used them, with a preview and details of the selected one. Pick a collection from the menu next to the search field to show only that collection. Creating or editing a snippet replaces the list with a form; ⌘↵ saves and Esc goes back without saving.

| Key | Action |
| --- | --- |
| ↵ | Copy the snippet, with placeholders filled in |
| ⌘↵ | Paste it into the app you were using |
| ⌘O | Open it in another app (links in a browser, anything else as a text file) |
| ⇧⌘P | Pin or unpin it |
| ⌘E | Edit it |
| ⌘D | Duplicate it |
| ⌘N | Create a snippet |
| ⌃X | Delete it, after confirming |
| ⌘K | Show all actions |

How often and when each snippet was last used is stored privately in `~/Library/Application Support/Tooki/snippet-usage.json`, so using a snippet never changes `snippets.json`.

### Emoji picker

Bind the `emoji` action to open a searchable emoji grid. Search matches names, keywords and shortcodes, so "like" finds 👍. Arrow keys move through it, Page Up and Page Down jump a screenful, Home and End go to the ends, ↵ pastes, ⌘↵ copies, and ⌘K offers Copy Shortcode. Recently used emoji are listed first. With snippet keywords on, typing an emoji's code between colons, such as `:rocket:`, replaces it with the emoji. Codes are GitHub-style shortcodes like `:+1:` or `:thumbsup:`, and the name with underscores also works, for example `:thumbs_up:`.

Emoji data comes from [emojibase](https://emojibase.dev) and ships inside the app. Emoji that this macOS version can't draw yet are hidden, and appear once macOS supports them. To pick up a new Unicode release, run `scripts/update-emoji.py`, which regenerates `Sources/TookiKit/Emoji/EmojiData.swift`.

### Clipboard history

Press Hyper+V to open it. The list is on the left (Pinned first, then Most Recent) and the selected entry is previewed on the right with its source app, size and copy counts, above the Copy, Paste, Drag and More buttons. Filter by typing, or pick a type (Text, Links, Colors, Images, Files) from the menu. Pinned entries are never removed by `maxItems`.

| Key | Action |
| --- | --- |
| ↑ ↓ (hold to repeat), Page Up/Down, Home/End | Move through the list |
| ↵ (or double-click) | Copy to the clipboard |
| ⌘↵ | Paste into the app you were using |
| ⌘O | Open With: search for an app to open an image, file or link with (Esc goes back) |
| ⌘S | Add to Shelf: pick a shelf or a new one. Files then ask whether to add a copy or the original. The shelf stays shown or hidden as it was |
| ⇧⌘P | Pin or unpin |
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
      { "key": "m", "action": "menuBar.search" },
      { "key": "t", "action": "open:com.apple.Terminal" }
    ]
  },
  "snippets": {
    "enabled": true,
    "keywordExpansion": true       // false keeps snippets in the snippets panel only
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

**Actions:** `search`, `clipboard`, `snippets`, `emoji`, `shelf.manager`, `menuBar.search`, `open:<bundle id or app path>` (opens the app, or hides it when it's already in front).

Hyper + any unbound key is passed on as ⌃⌥⇧⌘ + key, so it also works with shortcuts in other apps.

### snippets.json

```json
[
  {
    "id": "8B1D248E-A982-4CE4-AF51-AA88B46FFB5C",
    "name": "Email reply",
    "keyword": ";thanks",
    "collection": "Work",
    "text": "Hi {argument:name},\n\nThanks for reaching out. {cursor}\n\nBest,\nMohammad",
    "isPinned": true,
    "createdAt": "2026-11-01T09:30:00Z",
    "modifiedAt": "2026-11-04T16:12:00Z"
  }
]
```

`id`, `isPinned`, `createdAt` and `modifiedAt` are optional when you write snippets by hand. The snippets panel sets them when you pin, create or edit a snippet. Placeholders:

| Placeholder | Result |
|---|---|
| `{date}` / `{date:yyyy-MM-dd}` | Today's date, with an optional format |
| `{time}` / `{time:HH:mm}` | The current time |
| `{clipboard}` | The current clipboard text |
| `{cursor}` | Where the cursor ends up after insertion |
| `{argument:name}` | Asks for a value before inserting |

## Shelf

The shelf is a floating spot to collect files while you move between folders and apps. Hold **Shift** while dragging anything to make it appear next to the pointer, then drop onto it. You can also open it from the menu bar menu, or from the Shelf Manager (bind the `shelf.manager` action to a shortcut, then press ⌘S to show or hide every shelf).

It holds files and folders. Dropped or pasted text, links and images are saved as files (`.txt`, `.webloc`, `.png`) so you can drag them into any app. Text files are named after the first words, letters and digits only, up to 30 characters. Items stay on the shelf after Tooki restarts. When a file is moved or deleted outside Tooki (in Finder, yazi or a script), its item leaves the shelf within a couple of seconds.

You can have several shelves, each in its own floating panel. Every Shift-drag opens a fresh shelf next to the pointer (dropping on a shelf that's already showing adds to that one instead). Shelves are named Shelf 1, Shelf 2 and so on; rename one with **Rename** in its ⋯ menu. Drag a shelf by its name or any empty part of its header or footer (the pointer turns into a hand). A focused shelf has a soft blue glow. The menu bar menu and the Shelf page list every shelf, with New Shelf and Clear All.

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
- Items you drag out leave the shelf (turn off `removeAfterDragOut` to keep them). A shelf is never closed for you, even when it's empty: close it yourself with **Delete Shelf**. The one exception is a Shift-drag shelf that you didn't drop anything on. For originals, Finder decides between copy and move: dragging to a folder on the same disk **moves** the file. Use a copy when that matters.

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

### Searching shelves

The `shelf.manager` action (or **Shelf Manager** in search) opens every shelf in a panel laid out like clipboard history. It lists your shelves, most recently used first, with a few of their items and a summary on the right. Searching also finds shelves holding a matching file. Return opens a shelf to list its items, with a preview and where each file lives. Drag an item from the list into any app.

| Key | Shelves | Items of a shelf |
| --- | --- | --- |
| Return | Open the shelf | Open the file |
| ⌘Return | Show the shelf on screen | |
| ⌘K | Actions | Actions |
| ⌘O | | Open With |
| ⌘Y | | Quick Look (shows the shelf to preview it) |
| ⇧⌘F | | Show in Finder |
| ⌘C, ⇧⌘C | | Copy the file, copy its path |
| ⌘R | Rename the shelf in the search field (↵ saves, Esc cancels) | Rename the file |
| ⌘S | Show or hide every shelf (keeps the panel open) | Show or hide only this shelf |
| ⌘N | New shelf: shows it without leaving the panel and selects it | New shelf |
| ⌃X | Close the shelf (asks first when it holds copies) | Remove from the shelf |
| Esc | Close the panel, or go back to search | Back to the shelves |

On a shelf, ⌘K › **Paste from Clipboard** adds what is on the clipboard now: one or several files, an image, text or a link. Files ask whether to add a copy or the original.

`config.json` options under `shelf`: `enabled`, `shiftDragOpens` and `removeAfterDragOut` (all `true` by default).

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

`tooki-shelf list` runs `Tooki shelf list`, which prints one line per shelf (id, name and item count, separated by tabs), most recently used first. `Tooki shelf items <name or id>` prints the path of each file on that shelf, one per line. Both read what Tooki saved, so they work even when Tooki isn't running. Set `TOOKI_BIN` if Tooki isn't in `/Applications`.

With fzf, pick files with Tab and shelve them:

```sh
fzf -m --print0 | xargs -0 tooki-shelf
```

In yazi, use a plugin that adds the selection (or the hovered file). When shelves are open, [fzf](https://github.com/junegunn/fzf) asks which one (or a new one), then you choose to add a copy or the original. It can also do the reverse: pick files from a shelf with fzf (Tab marks, Ctrl-A marks all), then pick Copy or Cut, as if you'd pressed yazi's `y` or `x`; then press `p` in a folder. Without fzf it selects every file on the shelf so you can use `y` or `x` yourself. Save it as `~/.config/yazi/plugins/tooki-shelf.yazi/main.lua`:

```lua
--- `plugin tooki-shelf -- add` adds the selected files and folders (or the hovered one) to a Tooki shelf.
--- fzf picks the shelf (or a new one) when shelves are open, then a menu asks: c adds a copy, o the original.
--- `plugin tooki-shelf -- get` picks files from a shelf with fzf, then a second fzf asks whether to copy or cut them.
--- Then press p in a folder. Without fzf it selects every file on the shelf instead.

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

--- Open shelves from `Tooki shelf list`, most recently used first. Returns nil when Tooki can't run.
local function open_shelves()
	local output = Command(tooki):arg("shelf"):arg("list"):output()
	if not output or not output.status.success then
		return nil
	end
	local shelves = {}
	for line in output.stdout:gmatch("[^\n]+") do
		local id, name, count = line:match("^([^\t]+)\t([^\t]*)\t(%d+)$")
		if id then
			shelves[#shelves + 1] = { id = id, name = name, count = tonumber(count) }
		end
	end
	return shelves
end

--- Asks which of `shelves` to use: 1-9, plus n for a new one when `allow_new` is set.
--- Returns the shelf, "new", or nil when cancelled.
local function ask_shelf(shelves, allow_new)
	local cands = {}
	for i = 1, math.min(#shelves, 9) do
		local shelf = shelves[i]
		local items = shelf.count == 1 and "1 item" or string.format("%d items", shelf.count)
		cands[i] = { on = tostring(i), desc = string.format("%s (%s)", shelf.name, items) }
	end
	if allow_new then
		cands[#cands + 1] = { on = "n", desc = "New shelf" }
	end
	local choice = ya.which({ cands = cands })
	if not choice then
		return nil
	end
	return shelves[choice] or "new"
end

local function notify(content, level)
	ya.notify({ title = "Tooki Shelf", content = content, timeout = 3, level = level or "info" })
end

--- Runs fzf over `lines` with extra `args`. Returns its output ("" when cancelled), or nil without fzf.
local function run_fzf(lines, args)
	local child = Command("fzf"):arg(args):stdin(Command.PIPED):stdout(Command.PIPED):spawn()
	if not child then
		return nil
	end
	for _, line in ipairs(lines) do
		child:write_all(line .. "\n")
	end
	child:flush()
	local output = child:wait_with_output()
	return output and output.stdout or ""
end

--- Picks a shelf with fzf: the open shelves plus a new one. Returns the shelf, "new", "" when cancelled,
--- or nil without fzf.
local function choose_shelf_with_fzf(shelves)
	local lines = {}
	for i, shelf in ipairs(shelves) do
		local items = shelf.count == 1 and "1 item" or string.format("%d items", shelf.count)
		lines[i] = string.format("%d\t%s (%s)", i, shelf.name, items)
	end
	lines[#lines + 1] = "new\tNew shelf"

	local permit = ui.hide()
	local output = run_fzf(lines, { "--delimiter", "\t", "--with-nth", "2", "--prompt", "Add to shelf> " })
	permit:drop()

	if not output then
		return nil
	end
	local choice = output:match("^[^\t]+") or ""
	if choice == "new" then
		return "new"
	end
	return shelves[tonumber(choice)] or ""
end

--- Returns the shelf query (`shelf=<id>` or `shelf=new`), "" with no shelves open, or nil when cancelled.
local function pick_shelf()
	local shelves = open_shelves() or {}
	if #shelves == 0 then
		return ""
	end
	local shelf = choose_shelf_with_fzf(shelves)
	if shelf == nil then
		shelf = ask_shelf(shelves, true)
	end
	if shelf == nil or shelf == "" then
		return nil
	end
	return "shelf=" .. (shelf == "new" and "new" or shelf.id)
end

--- Asks whether to add copies or the originals. Returns true for copies, false for originals, nil when cancelled.
local function ask_copy()
	local choice = ya.which({
		cands = {
			{ on = "c", desc = "Add a copy (originals stay put)" },
			{ on = "o", desc = "Add the originals" },
		},
	})
	if choice == nil then
		return nil
	end
	return choice == 1
end

local function add_to_shelf()
	local paths = selected_paths()
	if #paths == 0 then
		return notify("Nothing to add", "warn")
	end

	local shelf = pick_shelf()
	if shelf == nil then
		return
	end
	local as_copy = ask_copy()
	if as_copy == nil then
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
end

local preview = [[if [ -d {1} ]; then ls -la {1}; else bat --color=always --style=plain {1} 2>/dev/null || cat {1}; fi]]

--- Lets you mark files with fzf, then asks whether to copy or cut them.
--- Returns the chosen paths ({} when cancelled) and whether to cut them, or nil without fzf.
local function choose_with_fzf(paths, shelf_name)
	local lines = {}
	for i, path in ipairs(paths) do
		lines[i] = path .. "\t" .. path:match("[^/]+$")
	end

	local permit = ui.hide()
	local marked = run_fzf(lines, {
		"-m", "--delimiter", "\t", "--with-nth", "2", "--preview", preview,
		"--prompt", shelf_name .. "> ", "--header", "Tab marks · Ctrl-A marks all · Enter continues",
		"--bind", "ctrl-a:select-all",
	})
	local action = ""
	if marked and marked ~= "" then
		action = run_fzf({ "Copy", "Cut" }, { "--prompt", "Then> ", "--no-sort" }) or ""
	end
	permit:drop()

	if not marked then
		return nil
	end
	local chosen = {}
	if action == "" then
		return chosen
	end
	for line in marked:gmatch("[^\n]+") do
		chosen[#chosen + 1] = line:match("^[^\t]+")
	end
	return chosen, action:match("^Cut") ~= nil
end

--- Picks files from a shelf (asking which one when there are several) and selects them, replacing the selection.
local function get_from_shelf()
	local shelves = open_shelves()
	if not shelves then
		return notify("Couldn't run Tooki at " .. tooki .. ". Check TOOKI_BIN", "error")
	elseif #shelves == 0 then
		return notify("No shelves open", "warn")
	end
	local shelf = #shelves == 1 and shelves[1] or ask_shelf(shelves, false)
	if not shelf then
		return
	end

	local output = Command(tooki):arg("shelf"):arg("items"):arg(shelf.id):output()
	if not output or not output.status.success then
		local reason = output and output.stderr:match("[^\n]+") or "Tooki didn't run"
		return notify("Couldn't read " .. shelf.name .. ": " .. reason .. ". Is Tooki up to date?", "error")
	end
	local paths = {}
	for path in output.stdout:gmatch("[^\n]+") do
		paths[#paths + 1] = path
	end
	if #paths == 0 then
		return notify(shelf.name .. " is empty", "warn")
	end

	local chosen, cut = choose_with_fzf(paths, shelf.name)
	if not chosen then
		notify("fzf isn't installed, so every file is selected", "warn")
		chosen = paths
	elseif #chosen == 0 then
		return
	end

	ya.emit("escape", { select = true })
	for _, path in ipairs(chosen) do
		ya.emit("toggle", { Url(path), state = "on" })
	end
	local count = #chosen == 1 and "1 item" or string.format("%d items", #chosen)
	if cut == nil then
		return notify(string.format("Selected %s from %s. Press y or x, then p in a folder", count, shelf.name))
	end
	ya.emit("yank", { cut = cut })
	notify(string.format("%s %s from %s. Press p in a folder", cut and "Cut" or "Copied", count, shelf.name))
end

return {
	entry = function(_, job)
		if job.args[1] == "get" then
			return get_from_shelf()
		end
		add_to_shelf()
	end,
}
```

Then add keys to `keymap.toml`. `T a` adds to a shelf: fzf picks the shelf (or a new one), then press `c` to add a copy (the safe choice) or `o` for the originals. `T s` selects a shelf's files: mark them in fzf, then pick Copy or Cut and press `p` in a folder:

```toml
[[mgr.prepend_keymap]]
on   = ["T", "a"]
run  = "plugin tooki-shelf -- add"
desc = "Add to Tooki shelf"

[[mgr.prepend_keymap]]
on   = ["T", "s"]
run  = "plugin tooki-shelf -- get"
desc = "Select from Tooki shelf"
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
