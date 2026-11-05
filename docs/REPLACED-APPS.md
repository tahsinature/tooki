# Apps Tooki Replaces

A running record of the separate apps Tooki makes unnecessary, and how much space and
cost that saves. Use it as a reference for release notes, the website or anything else.

## At a glance

| | Size |
| --- | --- |
| **Tooki** (all modules, version 0.1.0 in /Applications) | **3.4 MB** |
| Apps replaced so far (measured or estimated below) | **~90 MB** and counting |

Update the totals whenever a row below changes.

## Replaced apps

Apps I actually used and uninstalled because Tooki covers them.

| Tooki module | Replaces | App size | Price | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| Shelf | [Dropover](https://dropoverapp.com) | ~90 MB (estimate, to confirm) | Paid | Replaced | Covers the shelf itself: drag in, drag out, links or copies, plus a `tooki://` URL scheme and a yazi plugin. Leaves out sharing, AirDrop and email actions on purpose. |

## Also covers

Well-known apps each module overlaps with, even if I never used them. Fill in sizes once
measured, and move a row up to "Replaced apps" when it applies.

| Tooki module | Similar apps | What Tooki covers |
| --- | --- | --- |
| Hyper Key | Hyperkey, Karabiner-Elements (for this one use) | Caps Lock as an extra modifier |
| Snippets | TextExpander, Espanso | Keyword text expansion in any app |
| Clipboard | Maccy, Paste, Clipy | Searchable clipboard history |
| Shelf | Dropover, Yoink | Floating file shelf |
| Menu Bar | Bartender, Ice, Hidden Bar | Hiding and searching menu bar icons |
| Keep Awake | Amphetamine, Caffeine, KeepingYouAwake | Preventing sleep |
| Shortcuts | Thor, rcmd, Manico | Opening apps and running actions with a keystroke |

## How to measure

Measure the installed app bundle, so every number is compared the same way:

```sh
du -sh /Applications/Tooki.app
du -sh "/Applications/<Other App>.app"
```

Note the version and date next to a number when it matters, since app sizes change between releases.

## Talking points

- One small native app instead of several, each with its own updates, permissions and menu bar icon.
- Tooki is about 3.4 MB in total, while Dropover alone is roughly 90 MB.
- Everything is configurable from one JSON file and scriptable through `tooki://` links.
