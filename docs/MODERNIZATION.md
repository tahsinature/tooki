# Modernization milestones

## Foundation and Clipboard reference feature

The first milestone preserves the current app appearance and saved-data formats while establishing real module boundaries:

- `TookiKit`: portable data models and business rules.
- `TookiDesignSystem`: panel/settings themes, shared rows, grouping, search headers, list-detail layout, popups, footer controls, focus, and list navigation. It depends on `TookiKit`, never on a feature or the application.
- `ClipboardFeature`: TCA state, actions, derived results, and clipboard service dependencies. It depends on `TookiKit` and TCA, never on AppKit or the design system.
- `SnippetFeature`: TCA search, collection filtering, activity ordering, selection, drafts, pinning/deletion and copy/paste requests. It has the same portable dependencies as `ClipboardFeature`.
- `SearchFeature`: portable launcher metadata, fuzzy/frecency ranking, grouping, selection and action-menu state for Root Search and Menu Bar Search. AppKit icons, calculator integration, execution and launcher-history persistence stay in the native adapter/controller.
- `Tooki`: native application lifecycle, service implementations, window controllers, and features awaiting migration. `ClipboardPanelModel` adapts the feature store to the shared panel and native action menus.
- `ComponentGallery`: a separate developer application using synthetic data and the production design-system components. It does not start clipboard monitoring or load configuration/history.

Clipboard result filtering is recomputed when history or filters change. Rendering and selection changes reuse that result. Copy, paste, pin and delete requests pass through `ClipboardClient`. The native controller handles window closure, Quick Look, Open With and Shelf integration. Paste's focus-restoration delay is tested with a controllable clock.

Existing JSON history and configuration stay in their existing locations. Database migration is a later milestone. Pinning, grouping preferences, position restoration, actions submenus and keyboard navigation must remain compatible.

## Commands

```sh
make gallery       # run the interactive shared-component gallery
make gallery GALLERY_ARGS=--stress-list # 5,000 synthetic entries for UI profiling
make test          # reducer, domain, native panel and screenshot tests (full Xcode)
make visual-test   # only screenshot regression tests
make dev           # build and open the development app
```

Use the Makefile so builds select a compatible SDK. When the selected SDK differs from the toolchain default, the Makefile uses `.build/compatible-sdk` and builds macro dependencies from source. This avoids SDK-incompatible macro prebuilts and SwiftPM's persisted-prebuilt issue ([SwiftPM #10756](https://github.com/swiftlang/swift-package-manager/issues/10756)). Initial dependency builds are slower; subsequent builds reuse these artifacts.

Dependencies are pinned in `Package.swift` and `Package.resolved`. Package resource bundles, including privacy manifests, are copied into the signed app's Resources directory. `Resources/ThirdPartyNotices.txt` includes the resolved packages' licenses and notices; refresh it when upgrading dependencies.

Collections is temporarily locked to 1.2.1 in `Package.resolved` because newer releases compile Swift 6.4 standard-library APIs such as `BorrowingIteratorProtocol` that are absent from SDK 26.5. Reassess this lock with the full Xcode SDK. Update it once the currently supported toolchains compile the newer release and the regression suite passes. Likewise, remove the fallback build path and `ViewState` alias if the supported toolchains no longer need them.

Tests require full Xcode because SnapshotTesting imports XCTest, which Command Line Tools do not include. Screenshot comparisons are part of normal `make test`; `make visual-test` filters the suite to those comparisons. The temporary `VisualTests` trait and explicit testing-plugin flags were removed after Xcode validation. This also keeps SnapshotTesting in the resolved dependency graph when switching between app builds and tests.

Visual references under `Tests/DesignSystemTests/__Snapshots__` and `Tests/FeatureVisualTests/__Snapshots__` contain reviewed light/dark images. The fixture attaches its hosting view to a window and forces display so thin dividers and text rasterize correctly. It does not use a fixed sleep. The initial reference-less run records images and fails; inspect them before rerunning. Compare snapshots on the same macOS/toolchain and display scale; system font/symbol rendering can vary between environments. Review intentional changes before recording replacement references.

## Baseline recorded before migration

Local measurements on this workstation, with Swift 6.4 and SDK 26.5:

| Check | Result |
| --- | --- |
| Existing tests | 276 passed (25 native app, 251 domain) |
| `make test`, build and execution | 51.45 seconds |
| Earlier release one-file timestamp rebuild, including packaging | 48.13 seconds |
| Earlier debug one-file timestamp rebuild, including packaging | 28.99 seconds |
| Earlier warm debug packaging | 3.27 seconds |

Build timings are samples, not performance guarantees. Initial dependency compilation must be reported separately from warm rebuilds. Startup latency, memory use and large-history UI responsiveness have not yet been profiled with Instruments.

## Earlier foundation validation with Command Line Tools

- 282 core tests passed: 26 native panel tests, 251 domain tests, 5 Clipboard reducer tests.
- Both debug and release compilation passed. The first release build took 288.21 seconds, including source compilation of macro dependencies with the fallback SDK.
- The debug application builds and passes strict code-signature verification. Its package resource bundles are included.
- The gallery was reviewed in light and dark appearance. Command-arrow selection, actions, keyboard filtering and empty search states were exercised through the native UI.
- A warmed debug app/package build took 5.79 seconds; a timestamp-only rebuild of the extracted `SectionHeader` took 7.26 seconds.
- Other no-change builds unexpectedly recompiled dependencies and took 60–80 seconds on the Command Line Tools/fallback-SDK setup. The cause is not yet confirmed. Do not present the faster sample as a reliable build-time guarantee; repeat measurements under full Xcode.
- Snapshot reference recording and Instruments measurements were pending full Xcode installation at this stage. See the Xcode validation below for current results.

### Follow-up verification on November 14, 2026

At the start of this pass, full Xcode was absent; `make visual-test` correctly stopped with its full-Xcode requirement, and `xctrace` was unavailable. Xcode was subsequently installed through the Mac App Store; see the Xcode validation below.

The existing 282 core tests passed again. Two consecutive unchanged debug app/package builds took 61.41 and 60.43 seconds. Both traversed dependency build steps; during the subsequent optimized rebuild, the active compiler was compiling SwiftSyntax with `-O`. This identifies expensive work in that rebuild, but does not establish why dependency artifacts are being rebuilt. Do not claim the build-cache problem is resolved.

A temporary optimized executable linked the production `ClipboardFeature` and TCA objects, populated synthetic history, selected the final item, and timed one `.moveSelection(-1)` action. Before the navigation fix, samples were 1.86 ms for 100 items, 170.35 ms for 1,000 items, and 5,056.55 ms for 5,000 items. Filtering those same collections took 0.12, 0.64 and 4.17 ms respectively. These are store-action samples, not rendered-frame or end-to-end interaction measurements.

The reducer was looking up `selectedItem` inside the predicate of another list search, causing repeated full-list searches near the end. It now captures `selectedID` once and searches directly, preserving the first-item fallback for empty or stale selection. A 5,000-item regression covers bottom navigation and both fallback cases.

The optimized rebuild passed. In three post-fix runs of the same benchmark, moving from the bottom took 0.012–0.013 ms for 100 items, 0.045 ms for 1,000 items and 0.207–0.217 ms for 5,000 items. Filtering 5,000 items took 2.83–2.98 ms. These measurements verify the reducer improvement, not SwiftUI rendering performance. All six Clipboard reducer tests passed after the fix, including the new large-history regression. The pre-fix full suite had 282 passing tests; the new test increases the core test inventory to 283, with the post-fix rerun limited to the six affected reducer tests.

Code review also found the same nested-search pattern in `SnippetPanelModel.moveSelection`, where `selectedSnippet` recomputes ordered results inside the search predicate. It was subsequently addressed in the November 15 Snippets migration below.

### Build-trace investigation

SwiftPM's `--experimental-task-backtraces` and `--experimental-trace-events-file` confirmed the intermittent no-change rebuild cause. Consecutive identical invocations alternated the compiler task environment between `TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault` and `TOOLCHAINS=org.swift.CommandLineTools`. The associated SDK stat-cache path and testing-plugin arguments also changed, invalidating the tasks despite unchanged source files. Instrumented app/package builds took 63.64 and 58.83 seconds; an identical direct build that retained its toolchain identity took 5.07 seconds. Verbose tracing itself changes compiler arguments, so the initial transition into tracing was excluded from that comparison.

This matches [Swift Build issue #1861](https://github.com/swiftlang/swift-build/issues/1861), which identifies nondeterministic selection between two toolchain registrations sharing the Command Line Tools path. An [upstream fix](https://github.com/swiftlang/swift-build/commit/da7d609689527ee174485c9d1cdf86a13f0c5965) makes lookup deterministic and also addresses the missing TestingMacros problem documented in [issue #1870](https://github.com/swiftlang/swift-build/issues/1870). Xcode 27.2 (27B52) is now installed and licensed with the user's authorization. Swift 6.4.2, SDK 27.2 and Instruments 27.2 work. The Makefile prefers the installed Xcode for this project and respects an explicit `DEVELOPER_DIR`; it does not change the system selection. The system selection was also observed pointing to Xcode after first-launch setup. Do not attribute the earlier intermittent rebuild solely to Makefile packaging.

The explicit testing-plugin argument previously used by `make test` independently changed compiler arguments when switching from app builds. The full suite passed with Xcode's native plugin discovery; testing now requires full Xcode and no longer supplies the workaround. Command Line Tools app builds retain the SDK fallback and `ViewState` alias.

The gallery's `--stress-list` launch argument supplies exactly 5,000 synthetic rows to the existing shared list-detail panel, grouping, navigation and popups. The default four examples remain available without the argument. This isolates shared-component profiling from clipboard monitoring, services and user data; it does not measure full-app startup or storage costs.

The large-list gallery built and passed strict signature verification. Native UI checks confirmed that Command-Down renders `Sample entry 5000` in both appearances, Command-Up reveals the first row and group headings, Page Down selects the eleventh row from the first item at the current panel size, Page Up returns to the first item, and the actions popup opens. Searching `Sample entry 5000` produces that single result. These checks verify behavior and visible rendering, not frame-rate or latency metrics.

## Xcode validation

- Xcode 27.2 (27B52), Swift 6.4.2, macOS SDK 27.2, Instruments 27.2; host macOS 27.0.1.
- Normal `make test` passed all 284 tests: 251 domain, 26 native panel, 6 Clipboard reducer, and 1 visual test comparing both reviewed appearances.
- The two screenshot references use the window's 2× display scale. Initial unattached-view captures omitted half-point dividers; attaching the hosting view to a window and forcing display corrected the fixture. Production styling was unchanged. The final fixture passed twice after removing its temporary 100 ms sleep.
- Two consecutive unchanged debug app/package builds took 6.14 and 5.87 seconds. Their Swift build stages reused the on-disk description, replacing the earlier intermittent 60-second rebuilds on this workstation. This verifies the chosen Xcode environment, not a fix to the installed Command Line Tools.
- A timestamp-only rebuild of `SectionHeader.swift` took 7.82 seconds including packaging/signing, compared with the earlier 28.99-second debug sample before module extraction. Timings remain local samples.
- The updated development app passed strict signature verification and its bundled third-party notices match the source, including SnapshotTesting's notice. SnapshotTesting remains in `Package.resolved` during ordinary app builds.
- Instruments recorded an optimized gallery launch and two navigation sessions without a concurrent compiler workload. A 35-second detailed SwiftUI capture flagged 24 hitch events (maximum 433.316 ms); sampled stacks also showed substantial tracing overhead. A separate 30-second Animation Hitches capture recorded zero hitch events while top/bottom jumps, paging, popup actions and filtering were exercised. Templates and input timing differ, so this is an instrumentation-sensitive finding, not a controlled causal A/B result or a general frame-rate guarantee. Do not redesign the shared list based only on the detailed trace.
- The App Launch capture's initial-frame-rendering phase was 35.610 ms. This is one gallery lifecycle phase, not end-to-end Tooki startup. Instruments reported a sampling-period warning in that capture. Full-app startup and service/storage profiling remain separate work.
- One idle RSS sample after opening the optimized 5,000-row fixture was 116,752 KiB (about 114 MiB), with 0.0% CPU at that instant. This is resident memory, not peak memory, private footprint or leak verification.
- Local trace artifacts and compact metrics are under ignored `.playground/performance/2026-11-14/`. The approximately 5 GiB raw Animation Hitches trace was discarded after its compact hitch table was exported. Reproduce the fixture with `make gallery CONFIGURATION=release GALLERY_ARGS=--stress-list`; broad system-trace templates can produce large recordings. Traces stay outside source control.

## Following milestones

1. Migrate Emoji and Shelf using the established feature boundaries, then review the shared action-menu contract across Root Search and tools.
2. Evaluate Luminare in the gallery against Tooki's visual language and macOS 14 compatibility before adopting its components.
3. Add pinned formatting/linting tools and CI checks without extending the normal development build path.
4. Profile startup, search, scrolling, persistence and background work. Evaluate GRDB for history storage with a reversible data migration.
5. Evaluate Sparkle for updates and Inject/Xcode previews for visual iteration. Keep developer tooling out of release behavior.

The component gallery is a developer executable. This milestone introduces no new user-facing UI concept in Tooki, so the UI naming sketch is unchanged.

## Snippets migration, November 15, 2026

`SnippetPanelModel` now adapts `StoreOf<SnippetFeature>` to the existing shared panels, action menus, `JSONDocument<[Snippet]>`, usage history and native inserter. The reducer caches filtered, activity-sorted, pinned-first results; keyboard navigation performs one direct selected-ID lookup instead of repeatedly filtering, sorting and grouping inside another search. Large keyboard offsets are bounded before addition.

The reducer owns draft creation, duplication, cancellation, validation, save timestamps and selection after save/delete. UUIDs and dates are dependencies. Existing behavior is preserved: duplicate drafts have a new ID and empty keyword, conflicting keywords produce a warning without blocking save, and saving clears search/collection filters only when needed to reveal the saved snippet. JSON schema and locations are unchanged.

Document edits remain synchronous in the native adapter, retaining the existing JSON document's debounced disk saving, external-reload and symlink behavior. External snippet/usage changes refresh the store through the panel's observation and presentation hooks without discarding the current draft. Copy/paste requests pass through `SnippetClient` to the existing usage recorder and placeholder-aware inserter, including its argument prompt and focus-restoration handling. No additional paste delay is introduced.

Shared rows, grouping, popups, form layout and keyboard components are unchanged. There is no new user-facing UI concept, so the naming sketch does not need an update. Focused tests cover reducer behavior, 5,000-item navigation and native document/panel integration. Native panel fixtures explicitly supply deterministic UUID/date dependencies.

Validation: all 292 tests passed (251 domain, 27 native panel, 7 Snippets reducer, 6 Clipboard reducer and 1 light/dark visual test). The debug development app built, packaged and passed strict code-signature verification. No real snippet or usage files were changed by the new tests.

A temporary optimized benchmark harness linked the production debug `SnippetFeature`/TCA objects and timed one `.moveSelection(-1)` action from the final item. Three runs measured 0.251–0.258 ms for 1,000 snippets and 1.356–1.441 ms for 5,000 snippets, with selection assertions. These are reducer/store measurements using debug libraries, not rendered UI latency or directly comparable to the earlier optimized Clipboard benchmark. Full profiling was not repeated for this feature migration.

## Root Search migration and root-shortcut routing, November 15, 2026

`SearchModel` now adapts `StoreOf<SearchFeature>` to the existing launcher view. The reducer owns fuzzy/keyword/text matching, history-based ranking, recent/grouped results, result selection, action-menu presentation/query/selection, calculator placement and identity-preserving refresh. Navigation bounds large offsets before addition. Native rendering rows are cached when results change; selection does not repeatedly remap the source list.

Portable `SearchEntry` and action metadata contain no AppKit images or executable closures. The adapter retains the existing calculator callback, native images and commands. Calculator output, history and a ranking timestamp enter the reducer as explicit snapshots, allowing deterministic reducer tests. The controller keeps its existing execution, focus-restoration and history-file behavior. Saved data formats and shared visual components are unchanged.

The root-search shortcut previously relied on an app-wide local event monitor using `NSApp.keyWindow`. `FloatingPanel` and `ShelfPanel` now route the configured shortcut from their own `sendEvent` and `performKeyEquivalent` entry points, before editors, filter menus or actions consume it. Configuration and shortcut-recorder pause state are still read live. The old event monitor is removed.

A live diagnostic trace showed Root Search being presented and immediately resigning key status during the window transition. The navigation callback is now queued on the main actor after the old key event and close operation finish, without a fixed delay. Temporary diagnostics were removed. Regression tests await that callback explicitly and cover both Clipboard entry scenarios, shelf hiding, direct key equivalents, normal window event dispatch and live/disabled shortcut configuration. Physical-key verification of the revised handoff is pending user feedback; tool-driven global-hotkey reproduction was inconclusive.

Validation: all 300 tests passed with the final queued handoff: 251 domain, 29 native panel tests (including a two-case Clipboard dispatch test), 7 Snippets reducer, 6 Root Search reducer, 6 Clipboard reducer and 1 light/dark visual test. The earlier synchronous handoff also passed direct helper tests, which is why the added receiving-window and deferred-callback coverage matters. The development build is launched for physical-key verification; no success claim for that manual check is recorded yet.


## Emoji and Shelf migration, November 15, 2026

Emoji browsing now uses `StoreOf<EmojiFeature>`, including catalog search, recent/category sections, grid selection and action-popup selection. Reopening refreshes recent emoji without clearing the current query. Grid cells use the design system's `panelItemHighlight`, also used by `ResultRow`, for consistent hover and selection feedback. Hover does not move keyboard selection.

`ShelfManagerFeature` owns manager query, open shelf, rename mode, selected IDs and conversion presentation. The native adapter feeds immutable shelf/item metadata into the reducer on presentation and library changes. `ShelfFeature` owns floating-shelf selection, cursor, expansion/detail presentation and destructive-action confirmation. Confirmation expiry uses a cancellable TCA clock effect with a deterministic test, replacing the manual task timer. Navigation bounds offsets before adding them, including empty lists and extreme jumps.

File ownership, copying, conversion engines, drag providers, Quick Look, paste focus handling and saved JSON formats stay in the native application. Conversion-view retention still follows the existing closing animation; this intentional animation lifetime has not been replaced with an arbitrary reducer delay. New native bridge tests use temporary files and seeded shelves without persistence callbacks, never user shelves.

Validation: all 309 tests passed (251 domain, 31 native panel/adapter, 7 Snippets, 6 Search, 6 Clipboard, 3 Emoji, 4 Shelf, and 1 light/dark snapshot test). The debug app packaged successfully. Live screenshots confirmed the Emoji layout and floating Shelf render. Automated pointer-hover and physical ⌘Esc verification remain unconfirmed; do not infer either from the reducer tests. No additional library dependency or saved-data migration was needed.


## Physical ⌘Esc failure diagnosis, November 15, 2026

A physical-key trace confirmed that Command-Escape reached the shared CGEvent tap with the tool panel as `NSApp.keyWindow`, while neither the local AppKit monitor nor the receiving panel saw the command keydown. Plain Escape did reach those AppKit handlers. Window-only dispatch tests therefore did not reproduce the actual failure.

`ShortcutController` now gives the shared panel router first refusal before configured global commands. The router accepts only a visible, key Tooki tool panel, reads the root shortcut configuration live, and retains the existing window-handler fallback. The shortcut controller consumes the handled key release and repeats, including when the replacement Root Search has already become key. Paused recording and ordinary windows remain unaffected. No additional event tap or framework is introduced.

The event-tap regression tests exercise CGEvent input through `ShortcutController`, deferred Root Search presentation, repeat suppression, key release after Command has been released, hidden/ordinary windows and paused/disabled configuration. All 25 focused panel restoration tests passed. The user confirmed the replacement build opens Root Search correctly with ⌘Esc. Temporary key tracing was removed.


## Shelf image-conversion migration, November 15, 2026

`ShelfImageConversionFeature` now owns options, phase transitions, batch progress, preparation/save errors, reviewed results, navigation and preview-refresh sessions. `ShelfConversionClient` supplies native validation, image preparation, details, exact-row commits, preview cleanup and completion callbacks. The native model is an observable adapter; manual work-task ownership and refresh/closed flags were removed. Both floating Shelf and Shelf Manager consume this same adapter and reducer.

Preview generation and refresh are cancellable TCA effects. A native image operation may finish after cancellation, so the effect explicitly discards any unclaimed preview, including cancellation during delivery to the main actor. Refresh responses carry session IDs and cannot overwrite a later review. Failed items remain available for retry after partial batch saves. Files opened in external editors keep the existing seven-day retention policy. Saving remains non-cancellable and the native engine still validates source/review fingerprints and the exact original ShelfItem immediately before committing. No file formats, storage paths, user-facing concepts or shared styling changed.

Six new reducer tests cover batch failures/retry, cancellation with late native completion, save protection, opened-preview retention, stale refreshes, invalid preview recovery, review navigation and one-time completion. Two native integration tests use temporary fixture images to verify the real reducer/client commit path and removal protection without orphaned outputs. They bypass production preview pruning and do not load/save user shelves. Existing image-conversion engine tests continue to cover file-format and fingerprint behavior.

Validation: all 319 tests passed, including 35 native panel/adapter tests, 10 Shelf reducer tests and the shared light/dark snapshot test. No new dependency was required. The existing view-lifetime preview polling and outgoing-page animation retention remain intentional UI lifecycle behavior.


## Action filtering, menu-bar identities and feature visuals, November 15, 2026

Emoji action identity and titles now live in the portable `EmojiCommand`. The reducer owns the action query, filtered actions and selected command. The shared popup uses that real binding; keyboard navigation is bounded against the filtered list, and Return does nothing when there is no match. Reopening clears the action filter. Native icons, shortcuts and copy/paste execution stay in the app adapter.

Menu Bar Search now derives distinct IDs using the layout planner in left-to-right icon order, before sorting shown/hidden results for display. Each result retains its own native click target. Repeated Apple accessibility identifiers also receive occurrence suffixes. Tests cover repeated owner/title combinations, shuffled scanner order, visibility ordering, duplicate Apple identifiers and distinct execution callbacks. Search IDs now follow layout identities rather than titles; historical title-based menu-search recency keys are not rewritten. The history JSON schema and saved layout format are unchanged.

A separate `FeatureVisualTests` target renders production views using synthetic models and temporary files, without loading configuration, clipboard history, snippet usage or saved shelves. It covers 15 scenarios in both appearances: Root Search, duplicate menu-bar results, Clipboard, Snippets, a populated draft form, Emoji, filtered Emoji actions, long/empty Actions popups, Filter popup, Shelf Manager and all four conversion phases. Root/Menu Bar scenarios reuse the production mode configuration. Conversion pages use the production compact Shelf width.

The native conversion adapter accepts an initial reducer state for deterministic rendering of each phase. Fixtures use explicit color scheme, locale and key-control appearance; native windows stay off-screen and ignore mouse input. This prevents accidental hover highlights and user interaction from changing the reference images. The conversion-review fixture waits for its actual loading indicator to disappear instead of sleeping a fixed interval. Materials are captured against a controlled window backing; desktop-wallpaper blur is not certified by these references.

`make visual-test` includes both visual targets; normal `make test` includes them as well. Thirty reviewed feature images supplement the existing two row-state references. First-time reference recording intentionally reports missing-baseline failures; references are inspected before the comparison run. No application styling variants or additional app dependency were introduced.

Validation: all 324 tests passed, including 15 feature visual scenarios with 30 references and the original two row-state references. The final development app built, launched and passed strict code-signature verification. Live checks confirmed filtered Emoji actions, an empty action search, separate Stats rows, normal Menu Bar row spacing and return-to-root navigation. The initial emoji reference contained a desktop-pointer hover highlight; reviewed unhovered references replaced those two images after window isolation, with exact comparisons retained.


## Remaining timing fixes and Keep Awake, November 15, 2026

Shortcut Detective now matches deliveries by the original event timestamp and key code, tracks each check under a separate ID, and scopes completion to its listening session. Cancellable timeout tasks replace delayed dispatch callbacks. Stop/restart and deinitialization cancel pending work and remove native taps. Native delivery and sleep are injectable, allowing rapid repeated presses and stale sessions to be tested without activating real shortcuts.

Menu Bar layout loads carry request IDs and draft revisions. Cancelled or superseded loads cannot apply. Implicit lifecycle refreshes preserve dirty drafts; explicit Reload replaces the previous draft only if the user has made no intervening edits. Applying/saving invalidates older loads. Native scanning and arrangement remain unchanged.

`KeepAwakeFeature` owns activation policy, manual expiry, power-paused status, assertion responses and retry timing. The native adapter supplies running-app/power snapshots and a serial IOPM assertion owner. Workspace and power-source notifications replace the 15-second status poll; timed sessions use a cancellable clock and actual deadline. Failed assertion creation is visible and retries after 15 seconds. Pending responses are request-scoped; shutdown cancels effects and releases the native resource. Native observers and run-loop sources are cleaned up on shutdown/deinitialization. No settings or saved-data format changed.

The updater evaluation recommends Sparkle 2, with a concrete dependency, packaging, feed, signing and versioning plan in [UPDATER_EVALUATION.md](UPDATER_EVALUATION.md). Integration remains a separate decision because it changes release distribution; no additional framework or release credential was added.

Validation: the nine new functional regressions passed, covering event/session separation, stale and cancelled layout loads, native observer cleanup, precise expiry, power pause/resume, mode changes, assertion failure/retry and restarted sessions. Both visual targets and all other domain/reducer suites passed. The initial full run encountered four existing native window-focus failures while the screen was locked. Test-host activation experiments were removed. After the user unlocked the Mac, all 333 tests passed, including native focus and both visual targets. The development app built, launched and passed strict signing verification.


## Sparkle integration

Sparkle 2.10.1 now owns update checking, presentation, verification, installation and restart. The custom GitHub JSON checker and shell installer were removed. Packaging embeds and signs the versioned framework and helpers; releases generate an appcast, use increasing build numbers and require the configured Actions signing secret. The public key is embedded; the private key remains in the login Keychain and authorized GitHub Actions secret. All 335 tests passed. Local success, invalid-signature, download-failure, skip and retry paths were exercised with the production adapter in an isolated app. See RELEASING.md for the evidence and public-release checks still outstanding.
