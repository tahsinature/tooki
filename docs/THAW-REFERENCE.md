# Thaw reference

Tooki's menu bar organizer ports techniques from [Thaw](https://github.com/thaw-app/Thaw), an open source menu bar manager (GPLv3, a fork of Ice). Tooki is GPLv3 too. Ported files say so in their header comments.

## Pinned upstream

| Branch | Commit | Date | Use |
| --- | --- | --- | --- |
| `legacy/thaw-2` | `f8893186bd84fbe1012ee399523777dac438cad9` | 2026-11-06 | **Porting source** (Thaw 2, macOS 14+) |
| `development` | `92c959b6d3ca30d42988616b08073a609a1c0ede` | 2026-11-05 | Not used: Thaw 3 targets macOS 27 and is built on the closed PlatformRuntimeKit |

Paths below are relative to the Thaw 2 checkout.

## What maps where

| Thaw 2 | Concept | Tooki |
| --- | --- | --- |
| `Shared/Bridging/Shims.swift`, `Shared/Bridging/Bridging.swift` | Private CGS/SkyLight calls via `@_silgen_name`: menu bar window list, window frames, levels, "SetsCursorInBackground" | `Sources/Tooki/Modules/MenuBar/WindowServer.swift` |
| `Shared/Utilities/WindowInfo.swift`, `MenuBarItemService/SourcePIDCache.swift` | Item discovery from Window Server windows; owning app found by pairing windows with Accessibility elements | `MenuBarItemScanner.swift`, `MenuBarItem.swift`, `Sources/TookiKit/MenuBarSections.swift` (`MenuBarFrameMatcher`) |
| `MenuBarItemManager+EventHelpers.swift` | Scromble/barrier delivery with null marker events and event taps | `MenuBarEventRelay.swift` |
| `MenuBarItemEventTypes.swift`, `MenuBarItemManager+MoveEvents.swift`, `+MoveGeometry.swift` | ⌘-drag events aimed at window IDs (field 0x33, window-under-pointer fields, target PID), teleport move, drop points | `MenuBarItemEvents.swift` |
| `MenuBarItemManager+Click.swift` | Clicking an item with targeted events | `MenuBarItemEvents.swift`, `MenuBarItemPresser.swift` |
| `Thaw/Utilities/MouseHelpers.swift` | Hiding and restoring the pointer, waiting for idle input | `MenuBarItemEvents.swift` |
| `Thaw/MenuBar/MenuBarSection.swift` | Shown, hidden and always-hidden sections | `MenuBarOrganizer.swift`, `Sources/TookiKit/MenuBarSections.swift` |
| `Thaw/MenuBar/ControlItem/ControlItem.swift` | Divider status items stretched to 10,000 pt, autosave position seeding | `MenuBarDivider.swift` |
| `MenuBarItemManager+SavedLayoutApply.swift` | Restoring a saved layout | `MenuBarArranger.swift`, `MenuBarSnapshot.swift`, `Sources/TookiKit/MenuBarLayout.swift` |
| `Thaw/MenuBar/IceBar/IceBar.swift`, `IceBarLocation.swift` | The Thaw Bar panel and where it opens | `ThawBar/ThawBarPanel.swift`, `ThawBar/ThawBarView.swift`, `ThawBarPlacement` in `MenuBarSections.swift` |
| `Thaw/Utilities/ScreenCapture.swift`, `SLWindowListCreateImageFromArray` in `Shims.swift` | Capturing item images, also off screen | `ThawBar/MenuBarItemImageCapture.swift` |
| `Thaw/Events/HIDEventManager.swift`, `Thaw/Events/EventTap.swift` | Show on hover, click and scroll; rehide when the pointer leaves | `MenuBarRevealTriggers.swift`, `MenuBarTriggerZone` in `MenuBarSections.swift` |
| `Thaw/MenuBar/Appearance/MenuBarOverlayPanel.swift` | Menu bar tint | `MenuBarTintOverlay.swift`, `Sources/TookiKit/MenuBarAppearance.swift` |
| Settings panes | Options | `Settings/MenuBarView.swift`, `MenuBarRevealSettings.swift`, `ThawBarSettings.swift`, `MenuBarAppearanceSettings.swift` |

## Left out on purpose

Thaw's menu bar code is about 54,000 lines. Tooki keeps the techniques and drops the rest to stay small:

- **Clicking hidden items by temporarily moving them** into the shown section. Tooki reveals the section, clicks, waits for the menu to close and hides it again.
- **Move strategies:** only the teleport move is ported. Thaw's faithful drag, source-anchored moves, adaptive timeouts, move rescue and host recovery are not.
- **Layout features:** profiles, groups, the layout bar, item spacing, notch overflow handling, divider recovery and control item order repair.
- **Search panel:** Tooki has its own menu bar search.
- **Appearance:** only a solid tint. No wallpaper or adaptive tints, gradients, shapes, borders or shadows.
- **Triggers:** no tooltips, double-click actions, or alternate smart-rehide strategies. Triggers use NSEvent monitors instead of event taps, since nothing is intercepted.
- **Thaw 3's macOS 27 path.**

## Syncing with upstream

1. Fetch Thaw 2: `git clone --branch legacy/thaw-2 https://github.com/thaw-app/Thaw thaw2` (or `git -C thaw2 fetch`).
2. List upstream changes to the ported areas since the pinned commit:

   ```sh
   git -C thaw2 log --oneline f8893186bd84fbe1012ee399523777dac438cad9..origin/legacy/thaw-2 -- \
     Shared/Bridging Shared/Utilities/WindowInfo.swift MenuBarItemService/SourcePIDCache.swift \
     Thaw/MenuBar/MenuBarSection.swift Thaw/MenuBar/ControlItem Thaw/MenuBar/IceBar Thaw/MenuBar/Appearance \
     Thaw/MenuBar/MenuBarItems/MenuBarItemManager Thaw/Events Thaw/Utilities/MouseHelpers.swift Thaw/Utilities/ScreenCapture.swift
   ```

3. Read each relevant diff (`git -C thaw2 show <commit> -- <path>`). Port fixes for event delivery, private API signatures and macOS version quirks into the matching Tooki file from the table above.
4. Run `make test` and `make app`, then try hiding, showing, arranging and the Thaw Bar by hand.
5. Update the pinned commit and date in this file.
