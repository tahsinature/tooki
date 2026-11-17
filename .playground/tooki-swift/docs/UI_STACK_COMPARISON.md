# Tooki UI and technology options

Status: discussion document. No migration decision has been made.

This compares three approaches to making Tooki easier to develop, visually consistent and polished. It draws on the inspected Asyar source in `.playground/asyar-codebase` and Tooki's current architecture. Asyar has not been run or benchmarked for this comparison. Performance predictions and implementation effort are assessments, not measured results.

## At a glance

### Product priorities

The desired direction places particular value on:

- Faster frontend development with familiar TypeScript and CSS tooling, supported by a Rust native backend.
- The ability to ship on macOS, Windows and Linux.
- An established project structure and an extensible plugin system.
- Greater freedom to polish the interface and give each platform an appropriate, native-looking experience.
- A lighter development setup for less powerful machines: frontend work without full Xcode, with live UI updates instead of repeated native rebuilds.
- **No AI functionality.** If adopting an Asyar-derived application, remove AI features and their implementation rather than merely hiding them. This is a scope requirement, not work performed by this analysis.

These priorities make option 3 more attractive than a macOS-only comparison suggests. However, Rust does not itself guarantee faster development, and web styling alone does not reproduce native focus, accessibility or window behavior.

### Stack adoption versus an Asyar fork

Using Tauri, Rust and a web frontend does not automatically provide Asyar's application architecture or extension runtime. There are two distinct choices:

| Choice | Benefit | Cost |
|---|---|---|
| Build Tooki on the same technologies | Control the scope and architecture; introduce only required features | Build or integrate the application-level extension system ourselves |
| Fork/adapt Asyar | Existing services, extension SDK, worker infrastructure and components | Licensing review, removal of unwanted features, upstream maintenance and adaptation to Tooki's behavior |

Tauri native plugins and user-installable application extensions are different systems. Asyar has its own SDK, service registry and worker-host infrastructure for the latter. Supporting extensions also creates ongoing obligations for permissions, compatibility, lifecycle management and failures.

For an Asyar fork, AI removal needs a dependency audit covering frontend routes, services, Rust commands, providers, settings, onboarding, extension capabilities, networking and tests. Preserve non-AI utilities shared with those modules. The snippet service, for example, is called by an agent module but also operates independently; that is a reason to remove the caller carefully, not to delete the snippet service. No AI code has been removed during this review.

| | 1. Keep Swift and improve the current architecture | 2. Web UI with the existing native backend | 3. Full Tauri migration |
|---|---|---|---|
| Interface | SwiftUI and AppKit | React or Svelte inside a macOS webview | React or Svelte inside Tauri |
| Native services | Existing Swift services | Existing Swift services exposed through a new bridge | Rust services and plugins, with native adapters where needed |
| Styling | Shared Swift design tokens and components | CSS, Tailwind and shared web components | CSS, Tailwind and shared web components |
| UI iteration | Requires the Swift development workflow | Potentially fast frontend updates; development hosting must be integrated | Vite development workflow supported by the app setup |
| Reuse of current implementation | Highest | High for native services, limited for UI | Lowest; concepts and test scenarios remain reusable |
| Migration effort | Lowest | Medium to high | Highest |
| New integration complexity | Low | Swift-to-JavaScript bridge | Rust-to-JavaScript bridge plus native platform bindings |
| Cross-platform potential | Limited | Limited while the host and services remain macOS-specific | Stronger foundation, but each platform still needs feature implementations |
| Runtime speed | Existing baseline | Must measure | Must measure |
| Best fit | macOS integration and continuity | Web UI productivity while retaining macOS capabilities | Web productivity plus a serious cross-platform goal |

## 1. Keep Swift and improve the current architecture

Continue using `TookiDesignSystem`, SwiftUI/AppKit and TCA feature reducers. Borrow useful ideas from Asyar without changing the application stack.

### Pros

- Preserves working native features, including Shelf drag behavior, Hyper Key, menu-bar organization and Shortcut Detective.
- Keeps direct access to Apple frameworks without adding a web-to-native message boundary.
- Reuses existing reducer tests, native integration tests, visual snapshots and Sparkle release infrastructure.
- Has the smallest migration cost and lowest disruption to existing users and saved data.
- Can still adopt database-backed Clipboard storage, indexed search, stronger design checks and improved component documentation.
- Keeps most application development in one language.

### Cons

- Does not provide the familiar CSS, Tailwind and browser component workflow.
- Visual iteration continues to depend on Swift builds, previews or the component gallery.
- Some fine-grained layout and interaction behavior requires AppKit integration alongside SwiftUI.
- macOS-specific implementation offers little direct UI reuse for Windows or Linux.
- Shared components require continued discipline. Native UI does not automatically ensure consistent styling or keyboard behavior.

### What changes and what stays

This approach can improve storage, testing and design consistency incrementally. It does not address the preference to work primarily in TypeScript and CSS.

**Choose this when:** reliable macOS integration and minimal disruption matter more than changing the frontend workflow.

## 2. Web UI with the existing native backend

Keep the Swift application host and native services. Render selected interfaces in `WKWebView` using React or Svelte, and expose a small, typed command/event bridge to Swift.

This is a proposed architecture, not an existing Tooki capability. A mixed interface is possible: settings and content panels can use web UI while specialized native windows or drag surfaces remain native.

### Pros

- Provides CSS, Tailwind and reusable web components without immediately rewriting the native integrations.
- Makes layout, typography, hover states and theme experiments more familiar to a web developer.
- Allows incremental migration, beginning with one tool rather than replacing the entire app.
- Can preserve existing native storage and Sparkle updating initially.
- Keeps difficult macOS features close to their current, tested implementations.
- Provides evidence about the benefits of a web UI before committing to a larger rewrite.

### Cons

- Introduces a bridge that must handle command types, errors, cancellation, event subscriptions and window lifetimes.
- Adds a second UI technology and language to maintain.
- Existing SwiftUI views and their visual snapshots cannot be reused directly for the web interface.
- TCA reducers may remain useful, but their state and effects need an explicit integration strategy. They cannot simply be plugged into React or Svelte.
- Focus, keyboard shortcuts, accessibility and drag-and-drop must work across the webview boundary.
- Mixed native and web surfaces can drift visually unless they share equivalent tokens and interaction specifications.
- The frontend development server, resource packaging and production bridge need integration work.
- Does not make the application cross-platform while the host and services remain Swift/macOS-specific.

### Important architecture decision

Give each piece of state one owner. Keep system services and durable data native; keep temporary presentation state in the frontend where appropriate. Avoid duplicating the same feature state in both TCA and a JavaScript store.

**Choose this when:** frontend productivity is the main goal and retaining Tooki's native capabilities is a priority.

## 3. Fully migrate to Tauri

Use a Tauri application host, a React or Svelte frontend and a Rust backend. Port native services to Rust or expose retained native implementations through carefully scoped adapters.

Asyar demonstrates this general arrangement with Svelte 5, Tailwind 4, Tauri 2 and Rust. Its deeper macOS features still call Apple APIs.

### Pros

- Provides an established web frontend development and packaging workflow.
- Does not require the full Xcode application for ordinary macOS desktop development: Apple Command Line Tools can supply the native build prerequisites. Browser-only frontend work does not need Apple's native toolchain. This reduces setup and storage overhead compared with Tooki's current full-Xcode testing workflow. [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/).
- UI hot reload avoids recompiling the native backend for most styling and component changes. This can make routine UI iteration more comfortable on less powerful machines, although the benefit has not been benchmarked here.
- Supports the frontend component and styling ecosystem familiar from web development.
- Gives a stronger starting point for Windows and Linux support.
- Offers plugins for common desktop needs such as dialogs, global shortcuts, filesystem access and updates.
- Makes it natural to separate system services, storage and search from interface rendering.
- Rust can support efficient native data processing and background services.
- Offers an opportunity to redesign service boundaries and remove duplication during a deliberate rewrite.

### Cons

- Requires the largest rewrite of Tooki's UI, feature integration and native services.
- Native builds still require Rust and platform build tools. Initial Rust compilation and dependency updates can be resource-intensive; avoiding full Xcode does not guarantee faster builds or lower overall memory use. Full Xcode may still be useful for Apple-specific profiling and debugging, and is required for Tauri iOS development.
- Does not remove the need for macOS-specific code, permissions or platform behavior testing.
- Standard plugins do not establish parity for Hyper Key, Shortcut Detective, Shelf drag behavior or organizing other applications' menu-bar icons.
- Adds Rust and native framework bindings to the skills needed to maintain the project.
- Requires renewed validation of focus, paste targeting, keyboard layouts, accessibility, fullscreen Spaces and multi-monitor behavior.
- Requires a data migration or compatibility plan for existing history, settings, snippets and shelves.
- Requires release and update continuity planning. Existing Sparkle users must retain a working upgrade path.
- Introduces communication and serialization costs between the frontend and backend.
- Cross-platform support increases the testing and support matrix; it does not arrive automatically with the framework.
- A new framework can introduce different platform workarounds rather than eliminating them.

**Choose this when:** cross-platform support and a long-term Rust/web architecture justify the migration cost independently of visual styling improvements.

## Feature feasibility and migration risk

These ratings concern the cost of preserving Tooki's behavior, not whether a feature is theoretically possible.

| Feature | Keep Swift | Web UI + Swift | Full Tauri |
|---|---|---|---|
| Settings, grouping, rows and action menus | Improve existing components | Rewrite UI; bridge settings and actions | Rewrite UI and integrate backend |
| Root search | Retain current implementation | Reuse search services; bridge results | Port or replace services and UI |
| Clipboard history | Retain; optionally improve storage | Reuse capture/storage; bridge queries | Relevant Asyar implementation exists; parity and data migration required |
| Emoji | Retain current feature | Web grid with native copy/paste | Suitable for web UI; native paste still required |
| Snippet expansion | Retain native engine | Retain engine; replace management UI | Native listener/expander required; Asyar has a relevant implementation |
| OCR | Existing Apple Vision integration | Reuse native service | Asyar demonstrates Apple Vision access from Rust |
| Keep Awake | Existing IOKit integration | Reuse native service | Asyar demonstrates IOKit assertions from Rust |
| Quick Look | Existing native integration | Bridge to native preview | Asyar demonstrates native Quick Look hosting |
| Shelf and native drag-out | Retain existing behavior | High-risk boundary to prototype | Significant native work; complete equivalent not established |
| Hyper Key | Retain current event handling | Keep native | Significant port; equivalent not established |
| Shortcut Detective | Retain current event taps | Keep native | Significant port; equivalent not established |
| Menu-bar organization | Retain current integration | Keep native | Significant port; equivalent not established |
| Updates | Keep Sparkle | Keep Sparkle initially | Tauri updater available; transition must be designed |

## Deeper investigation: snippet expansion

**Conclusion:** Tooki's snippet capabilities can be implemented with a web UI and native backends. Swift is not a prerequisite for these capabilities, but platform-specific system integration is. Asyar already uses different keyboard listeners on macOS, Windows and Linux. Its current behavior should not be treated as a drop-in replacement for Tooki.

### What the inspected implementations do

| Behavior | Tooki | Asyar |
|---|---|---|
| macOS keyboard capture | Core Graphics event handling; consumes the last trigger character on a match | Global `NSEvent` monitor; observes typing without consuming it |
| Replacement | Deletes the preceding trigger characters, then inserts expansion | Emits a Rust event to TypeScript, resolves the template, writes the clipboard, calls Rust to delete the whole trigger and paste |
| Character interpretation | Reads Unicode text from the event | macOS monitor reads `charactersIgnoringModifiers` and lowercases characters |
| Clipboard handling | Snapshots clipboard representations, marks temporary content transient and restores if the clipboard has not changed | Inspected snippet path writes expansion text; no equivalent snapshot/restore in that path |
| Cursor placement | `{cursor}` produces a cursor offset, applied after paste | Equivalent behavior not established in the inspected expansion path |
| Arguments | Opens a native argument prompt for `{argument:name}` | Uses a shared template resolver; equivalent interactive prompt flow not established |
| Windows capture | Not implemented | Dedicated `WH_KEYBOARD_LL` listener |
| Linux capture | Not implemented | `rdev::listen` with an X11-based key resolver |
| Timing | Explicit waits before paste, cursor movement and clipboard restoration | Explicit waits between backspaces and before paste |

This corrects the earlier broad description of Asyar's listener: `rdev` is its Linux path; macOS and Windows use their own implementations.

Apple documents that global NSEvent monitors cannot modify or suppress delivery. Asyar's full-trigger deletion follows from that choice. A Rust macOS backend could instead use Core Graphics event taps, or call a retained Swift implementation through a native bridge. This is an implementation choice, not a Tauri limitation. [Apple event monitoring documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html).

### Recommended cross-platform structure

Keep the latency-sensitive expansion path in a native service that continues running while the manager UI is hidden:

1. Shared domain logic: snippet records, matching rules, placeholder parsing and expansion requests.
2. Platform adapter: keyboard capture, actual text interpretation, target application identity, deletion, insertion and clipboard preservation.
3. Web interface: snippet management, settings and argument prompts when requested by the service.

The macOS adapter can retain Swift initially or use Rust bindings to Apple frameworks. Windows needs its own input and clipboard adapter. Linux needs a clearly defined support matrix rather than a single claim of universal support.

Avoid requiring a JavaScript round trip for every ordinary trigger expansion. Use the frontend when a visible prompt is needed, with explicit target tracking and cancellation. Template syntax, date formats, Unicode deletion and cursor offsets need compatibility tests if their implementation language changes.

### Platform feasibility and boundaries

| Platform | Assessment | Material boundary |
|---|---|---|
| macOS | Comparable functionality is feasible using the same Apple APIs | Permissions, secure input, keyboard layouts, IMEs and focus still require testing |
| Windows | Native hooks and insertion APIs provide a feasible foundation | Input injection cannot normally target applications running at a higher integrity level |
| Linux X11 | Existing Asyar listener provides a starting point | Keyboard layout, insertion and target-application behavior need validation |
| Linux Wayland | Full parity is not established by the current Asyar implementation | Its X11 listener does not provide global capture for native Wayland applications; a separately researched backend/support policy is required |

Platform-specific code is the right extension mechanism, but it cannot guarantee access that an operating system or compositor does not expose. XWayland should not be advertised as universal native-Wayland support. [rdev listener limitations](https://docs.rs/rdev/latest/src/rdev/lib.rs.html), [Windows SendInput restrictions](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-sendinput).

Before calling a replacement equivalent, test rapid typing, cancellation, target-app changes, modifiers, Unicode and IME composition, clipboard restoration, placeholders, cursor positioning and behavior while the launcher is hidden. Existing timing delays in either project are not evidence of reliability across all applications.

### Snippet source evidence

- Tooki: [`SnippetExpander.swift`](../Sources/Tooki/Modules/Snippets/SnippetExpander.swift), [`SnippetInserter.swift`](../Sources/Tooki/Modules/Snippets/SnippetInserter.swift), [`Paster.swift`](../Sources/Tooki/Core/Paster.swift).
- Asyar platform dispatch: [`snippets.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/src/snippets.rs).
- Asyar macOS listener: [`macos/input.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/crates/asyar-platform/src/macos/input.rs).
- Asyar frontend expansion: [`snippetService.ts`](../.playground/asyar-codebase/asyar-launcher/src/built-in-features/snippets/snippetService.ts).
- Asyar insertion: [`commands/input.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/src/commands/input.rs).

## What Asyar teaches us regardless of stack

1. **Storage design matters independently of language.** Asyar uses paged Clipboard queries and a full-text index. Tooki can adopt similar ideas in Swift if history size and search requirements justify them.
2. **Keep processing near its data.** Filter large native datasets before returning results to the UI. Do not send frontend-owned arrays to the backend just to filter them.
3. **Make the design system enforceable.** Shared components, central tokens and automated compliance checks are more useful than relying only on written instructions.
4. **Separate background services from panel visibility.** Hiding the launcher must not unintentionally stop capture, expansion or other ongoing services.
5. **Web UI still needs deliberate interaction engineering.** Asyar explicitly handles first/last-row scrolling so section headings and padding remain visible.
6. **Framework choice does not remove consistency decisions.** Asyar's root grouping overrides shared heading styles. Tooki's stricter shared-component requirement should remain in force.

## Potential concerns

- **No proven speed advantage yet:** faster UI editing is a reasonable expectation for a web workflow, but application launch time, memory use and input latency must be measured.
- **Native behavior is part of the product:** reproducing screenshots is insufficient if paste targets, shortcuts or drag sessions become unreliable.
- **Accessibility needs explicit acceptance tests:** replacing native views with HTML changes the accessibility implementation and requires real VoiceOver verification.
- **User data and updates need continuity:** any migration must preserve saved data and provide a supported upgrade path.
- **Code reuse needs a licensing decision:** Asyar declares `GPL-3.0-only`. Review licensing before incorporating its implementation. Architectural study does not require copying its code.

## Recommended decision process

With cross-platform support now an explicit priority, option 3 deserves a focused feasibility prototype. Use retained Swift behind a native adapter where it reduces macOS risk. Option 2 remains useful as a transitional strategy, but does not by itself meet the Windows/Linux goal. A prototype is an experiment, not a commitment to maintain two complete applications.

1. Build a Clipboard interface using synthetic data, including shared search, grouping, rows, detail view and action popup components.
2. Exercise 5,000 rows, keyboard page navigation, first/last-item jumps and selection restoration.
3. Connect a narrow set of native capabilities: copy/paste, Quick Look and drag-out. Verify focus and return-to-root shortcuts.
4. Compare against Tooki's native implementation on the same machine: UI editing turnaround, reveal latency, input responsiveness, idle memory and CPU use.
5. Verify VoiceOver, text editing, light/dark appearance and behavior across fullscreen Spaces.
6. Choose a direction from the evidence: retain Swift, adopt selected web surfaces, or plan a complete Tauri migration.

Use React if familiarity is the primary frontend criterion. Use Svelte if its component and reactive-state model is preferred. Tauri supports either; that decision is separate from whether the native backend should remain Swift.

## Source pointers

Local implementation evidence:

- Tooki architecture: [`../Package.swift`](../Package.swift)
- Tooki Clipboard persistence: [`ClipboardHistory.swift`](../Sources/Tooki/Modules/Clipboard/ClipboardHistory.swift)
- Tooki native Shelf detection: [`ShelfDragWatcher.swift`](../Sources/Tooki/Modules/Shelf/ShelfDragWatcher.swift)
- Asyar frontend dependencies: [`package.json`](../.playground/asyar-codebase/asyar-launcher/package.json)
- Asyar native dependencies: [`Cargo.toml`](../.playground/asyar-codebase/asyar-launcher/src-tauri/Cargo.toml)
- Asyar design tokens: [`style.css`](../.playground/asyar-codebase/asyar-launcher/src/resources/styles/style.css)
- Asyar shared rows: [`LauncherListRow.svelte`](../.playground/asyar-codebase/asyar-launcher/src/components/list/LauncherListRow.svelte)
- Asyar grouping overrides: [`SectionedResultsList.svelte`](../.playground/asyar-codebase/asyar-launcher/src/components/list/SectionedResultsList.svelte)
- Asyar scroll boundaries: [`listScroll.ts`](../.playground/asyar-codebase/asyar-launcher/src/lib/listScroll.ts)
- Asyar Clipboard paging: [`clipboardHistoryStore.svelte.ts`](../.playground/asyar-codebase/asyar-launcher/src/services/clipboard/stores/clipboardHistoryStore.svelte.ts)
- Asyar native OCR: [`ocr/macos.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/src/ocr/macos.rs)
- Asyar power assertions: [`power/macos.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/src/power/macos.rs)
- Asyar panel lifecycle accommodation: [`sticky_window.rs`](../.playground/asyar-codebase/asyar-launcher/src-tauri/src/sticky_window.rs)

Framework documentation:

- [Tauri architecture](https://v2.tauri.app/concept/architecture/)
- [Calling Rust from the frontend](https://v2.tauri.app/develop/calling-rust/)
- [Tauri webview versions](https://tauri.app/reference/webview-versions/)
- [Tauri frontend overview](https://v2.tauri.app/start/)

The Asyar links depend on the local playground checkout being present.
