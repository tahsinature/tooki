# Migration audit and visual checks

November 15, 2026. Audit of remaining native tools and the migrated panel surfaces.

Follow-up status: findings 1 and 2 are fixed, and full feature/page visual fixtures have been added. The original audit evidence is retained below. Findings 3 and 4 have now been addressed with regression coverage; Keep Awake state has also been migrated. See MODERNIZATION.md and UPDATER_EVALUATION.md for the follow-up.

## Findings, in priority order

### 1. Emoji action search does not filter actions

**Confirmed in the running app.** Open Emoji, open Actions, and type `paste`. The field displays the text, but Copy Emoji, Paste Emoji and Copy Shortcode all remain visible; Copy Emoji remains selected. Root Search's popup correctly filters its actions.

`EmojiPanelView` passes `.constant("")` to the shared `ActionsPopup` and always supplies `EmojiAction.allCases`. Its Return handler also indexes the unfiltered cases. This differs from other consumers of the same popup.

Evidence: [EmojiPanelView.swift](../Sources/Tooki/Modules/Emoji/EmojiPanelView.swift), popup construction and Return handling.

Recommended fix: reducer-owned action query and filtered actions, with selection reset/clamping and Return executing the filtered selection. Reuse the established action-menu matching behavior. Cover typing, no matches, Return, clearing and reopening.

### 2. Menu Bar Search has colliding identities and visible row gaps

**Visible layout failure confirmed in the running app.** Menu Bar Search showed large blank gaps between rows that persisted after focusing the search and moving selection. Root Search's normal list did not show those gaps.

The result ID is `menubar-<bundle ID or app name>-<title>`. Multiple icons from one app can share a title and therefore an ID. The live Menu Bar layout editor showed multiple Stats and MenuBarAgent entries; searching Stats displayed one accessible result. The native SearchModel registry keeps the first item for each ID, so a collision can also map distinct icons to the same native action.

Evidence: [SearchItems.swift](../Sources/Tooki/App/SearchItems.swift), `menuBarItems()`; [SearchModel.swift](../Sources/Tooki/Modules/Search/SearchModel.swift), native item registry; [MenuBarLayout.swift](../Sources/TookiKit/MenuBarLayout.swift), existing distinct-icon identity rules.

The identity collision is a code defect. Its relationship to the observed blank gaps remains an inference until a targeted reproduction and corrected rendering verify it.

Recommended fix: reuse or extend the existing menu-bar identity utility, preserving separate actions for separate icons. Add a fixture containing multiple icons with the same owner/title. Verify both callback identity and actual rendered row positions.

### 3. Shortcut Detective can mix successive presses of the same key

**Code-level race; not reproduced by activating the live listener.** Pending presses are keyed only by key code. Each press schedules a callback 250 ms later that removes the entry for that key. A second press before the first callback overwrites the entry, allowing the older callback to finish the newer press and discard the earlier one. Stop/restart also leaves scheduled callbacks alive.

Evidence: [ShortcutDetective.swift](../Sources/Tooki/Modules/Shortcuts/Detective/ShortcutDetective.swift), `pending`, `handle` and `finish`.

Recommended fix: identify individual checks and listening sessions; associate completion with the originating check. Use controllable time and simulated delivery dependencies to test repeated keys, different modifiers and stop/restart.

### 4. Menu Bar layout loads can apply stale snapshots

**Code-level race; not deliberately triggered against the user's menu bar.** `load` awaits a snapshot and then replaces all editable lists without checking cancellation, request identity or intervening edits. The view can request loads through its lifecycle task and separate Reload button tasks.

Evidence: [MenuBarLayoutEditorModel.swift](../Sources/Tooki/Modules/MenuBar/Settings/MenuBarLayoutEditorModel.swift), `load`; [MenuBarLayoutEditor.swift](../Sources/Tooki/Modules/MenuBar/Settings/MenuBarLayoutEditor.swift), load entry points.

Recommended fix: a reducer-owned load session with cancellation/stale-response protection and an explicit rule for reloads while the draft is dirty. Keep native scanning and arranging behind clients. Test reversed response order and edits made during a scan.

## Styling and coverage gaps

- **Floating Shelf rows still own separate highlight styling.** They use accent-color selection and white text, while `ResultRow` and Emoji use `panelItemHighlight` and shared selected-background/rim tokens. This is confirmed in source; the compact Shelf row is a separate component. Agree on sharing highlight styling while retaining its compact layout before changing it.
- **Visual regression coverage is narrow.** The existing SnapshotTesting test renders shared row states and section headers in light/dark appearances. It does not cover complete panels, action/filter popups, Emoji, drafts or image-conversion screens. Passing that test does not validate all those surfaces.
- **Hover verification remains incomplete.** Source reuse of the shared highlight is checked. The available computer-use interface did not provide a direct pointer-hover operation, so live hover feedback is not certified by this pass.
- **Arbitrary-offset hardening is optional.** ActionsMenu and FilterPopup add offsets before clamping. The current keyboard helper uses half-range sentinel offsets, so the observed keyboard path avoids the initially suspected Int.max overflow. Do not describe this as a reproduced keyboard crash.

## Remaining native tools

| Area | Assessment and next boundary |
| --- | --- |
| Menu Bar organizer, layout and Thaw Bar | Highest state-management priority. Separate loading, editable layout, arranging and reveal state from native scanning/window-server services. Timing around native mouse delivery is not automatically removable by adopting a framework. |
| Shortcut Detective | Give each check a lifecycle and testable delivery timeout before changing the native event taps. |
| Keep Awake | A small candidate for reducer/client migration. Inject time, power status and assertion operations. Potential concern: statusText describes requested activation even when power restrictions or assertion failure leave isActive false, producing contradictory status text. This conditional behavior was found in source, not induced by changing power/configuration. |
| Updates | Still a custom native workflow. Existing installer checks the running app's designated signing requirement and attempts rollback on replacement failure. Future work should evaluate a maintained updater solution before expanding custom installation infrastructure. Release installation was not exercised; this is a dev build. |
| Hyper Key and global shortcut dispatch | Keep native event/remapping services at the system boundary. No new defect established in this pass. The previously fixed root shortcut remains functional in the inspected tool paths. |
| Shared settings components | Inspected settings use consistent cards/rows. Several reusable settings implementations still live under the app target; extraction can follow actual reuse needs rather than moving native config/services wholesale. |

## Verification performed

| Surface | Checks and result |
| --- | --- |
| Root Search | Live grouping, first/last keyboard jumps, Actions filtering, Filter search and popup layout passed in the inspected paths. Last-item content rendered and returning to the top exposed the first heading. |
| Clipboard | Live list-detail layout, footer, action no-match state and return-to-root checked. Date grouping was off in the user's current configuration. |
| Snippets | Live list-detail layout and blank draft form checked. Draft was cancelled without saving. Date grouping was off in the current configuration. |
| Emoji | Live grid/grouping and popup checked. Action filtering failed as described above. Return-to-root worked. |
| Shelf Manager | Live shelf list, item detail, long Actions popup and return-to-root checked without opening/changing files. |
| Menu Bar Search | Live rows, filtering and selection checked. Visible row gaps and identity concerns recorded above. No menu items were activated. |
| Settings | General, Menu Bar, Shortcuts/Detective, Keep Awake and About reviewed in the running app. Hyper Key settings were inspected in source; the live check was interrupted by user activity. |
| Image conversion | Prior migration's reducer/native integration tests cover conversion/commit behavior. Complete conversion screen screenshots were not generated in this audit. |
| Automated visuals | `make visual-test` passed: one test comparing the two existing light/dark row-state references. No new baselines were recorded. |

Live screen checks used the current dark appearance. Full-screen light-mode checks, every conversion phase, pointer hover and screen-reader interaction remain coverage gaps. No claim of complete visual certification is made.

## Recommended next pass

1. Fix Emoji action filtering and Menu Bar item identity; verify Menu Bar row spacing with a synthetic duplicate-icon fixture.
2. Add reusable full-panel and popup fixtures using the existing SnapshotTesting installation, including both appearances and conversion phases. Use these to address confirmed visual drift.
3. Migrate Shortcut Detective and Menu Bar layout state with deterministic time and stale-response tests.
4. Follow with Keep Awake status/state and an updater-tooling decision.

An alternative is to migrate all remaining tools before addressing coverage. That completes module boundaries sooner but leaves the confirmed UI bugs and broad visual blind spots in place longer. The focused fixes and reusable visual fixtures are the recommended order.


## Completed follow-up

- Emoji action search now filters real commands, selects the matching action and safely handles empty matches. Live typing `paste` displayed only Paste Emoji; an unmatched query displayed No matching actions.
- Menu Bar Search now uses distinct layout-derived identities and preserves each native click target. The live list rendered with normal row spacing; Stats search showed two separate rows instead of one collapsed result. This verifies that the identity correction resolved the observed spacing problem in the tested setup.
- `FeatureVisualTests` adds 15 synthetic panel/page/menu scenarios with 30 light/dark images. Together with the existing row references, both visual targets run in `make visual-test` and normal tests. Windows are isolated from desktop pointer activity; review-image capture waits for loading to complete.
- All 324 tests passed. The development app built, launched and passed strict code-signature verification. Live return-to-root navigation still worked. These references cover layout and rendered states, not desktop-dependent blur, screen-reader interaction or every pointer interaction.


## Remaining-work follow-up

Shortcut Detective now separates checks by event identity and listening session. Menu Bar layout loads reject stale/cancelled responses and preserve unsaved edits. Keep Awake uses reducer-owned policy, clock-driven expiry/retry and native power/workspace notifications, with clear paused/failure status. Nine new regressions cover these changes; after unlocking the Mac, all 333 tests passed. The updater evaluation is complete in [UPDATER_EVALUATION.md](UPDATER_EVALUATION.md); actual Sparkle dependency and release-pipeline integration remain a separate approval decision.


## Final source audit

The original findings above describe the pre-fix implementation. The completed follow-ups supersede those findings; the remaining native tools table is an architectural assessment, not a claim that every native service has been moved into a reducer.

- Root Search, Clipboard, Snippets and Shelf Manager use the shared `ResultRow`. Emoji cells reuse `panelItemHighlight`. Root Search and Emoji reuse `SectionHeader`; the list-detail tools use it through `GroupedPanelList`. Actions and Filter menus each have one shared rendering implementation.
- Floating Shelf rows now reuse `panelItemHighlight`, `primaryText` and `secondaryText`, preserving their compact layout, multiselection, drag targets and Details affordance. Selected rows no longer force white text on a platform accent background. A dedicated light/dark fixture covers selected and normal compact rows.
- No further confirmed dead implementation was found in the reviewed feature adapters and shared panel components. The native models bridge reducer state to AppKit images, window lifecycle, menus and services; they are not duplicate reducers to delete.
- Keep the shared scrolling edge targets and keyboard navigation revision signals. They implement the previously verified first/last-item scrolling fixes, including repeated navigation to the current selection.
- Keep native paste focus delays until a replacement is verified against delivery into another application. Search and Emoji explicitly wait for focus restoration; snippet insertion also allows the receiving application to process keyword deletion. Removing these delays just because reducers are available would not establish reliable delivery.
- Clipboard polling, native event taps, window/drag services and file conversion remain native boundaries. Moving their implementation into a new framework is outside this cleanup and requires evidence of an actual reliability or maintenance benefit.

This pass reviews source consistency and adds targeted compact-row visual coverage. It does not certify pointer hover, VoiceOver, or cross-application paste delivery through automated screenshots. Sparkle integration remains separate from the completed updater evaluation.

Validation: `make test` passed all 333 tests, including 16 full-surface visual scenarios (32 light/dark references) and the two shared-row references. The new compact-row references were inspected in both appearances.
