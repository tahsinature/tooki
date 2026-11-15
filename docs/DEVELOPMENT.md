# Developing Tooki

## Build from source

Requires macOS 14 or later and Swift 6.4. Full Xcode is required for tests, previews and Instruments. Apple's Command Line Tools (`xcode-select --install`) remain supported for app builds.

Build commands prefer `/Applications/Xcode.app` when installed. An explicit `DEVELOPER_DIR` overrides that project default. This does not change the Mac's global tool selection. Full Xcode is recommended: Command Line Tools 27.0 has an upstream toolchain-selection bug that can recompile unchanged dependencies. Tests use Xcode's native macro discovery and include screenshot comparisons in the normal suite.

```sh
make test      # domain, reducer, native panel and screenshot regression tests
make app       # builds and signs build/Tooki.app
make dev       # incremental debug build, signs and opens it, replacing any running copy
make install   # copies it to /Applications
make dmg       # builds build/Tooki.dmg
make info      # builds the app and shows its size, version, and requirements
make icon      # rebuilds Resources/AppIcon.icns after changing AppIcon.png (needs `brew install pngquant`)
make visual-test # shared-component and full feature/page screenshot comparisons
make gallery   # interactive gallery of production UI components with sample data
make gallery GALLERY_ARGS=--stress-list # same components with 5,000 synthetic entries
```

`make dev` skips release symbol extraction and stripping, and reuses the development icon until its source image or generator changes. The first debug build can take longer while Swift compiles the sources. Later builds reuse that work. `make app`, `make install` and `make dmg` still use release builds. Use `make dev CONFIGURATION=release` when checking runtime performance.

The app is signed with your "Apple Development" certificate when you have one. A stable signature means macOS keeps the Accessibility permission across rebuilds. Without a certificate, the Makefile signs ad hoc, and you may need to grant Accessibility again after rebuilding. Override with `make app SIGN_ID="..."`.

Use `make dmg ARCHS="arm64 x86_64"` for a universal build (needs full Xcode).

## Project layout

```
Sources/TookiKit/     Logic without UI (config, placeholders, keyword matching). Unit tested.
Sources/TookiDesignSystem/ Shared themes, components, panel layout and interaction behavior.
Sources/ClipboardFeature/  TCA state, actions and service dependencies for Clipboard.
Sources/SnippetFeature/    TCA snippet browsing, drafts and insertion dependencies.
Sources/SearchFeature/     Portable TCA ranking, selection and action-menu state for Root/Menu Bar Search.
Sources/EmojiFeature/      Portable emoji search, grid selection and action-menu state.
Sources/ShelfFeature/      Portable Shelf browsing, selection, confirmation and image-conversion workflow.
Tests/FeatureVisualTests/  Isolated light/dark panels, menus, forms and conversion-page references.
Sources/KeepAwakeFeature/  Portable power-policy state, precise expiry and assertion client.
Sources/ComponentGallery/  Standalone developer gallery using production components.
Sources/Tooki/Core/   Event tap, synthetic keys, pasting, storage, panels.
Sources/Tooki/Modules One folder per module (controller + settings view).
Sources/Tooki/App/    App entry, wiring, settings window.
packaging/            Homebrew cask.
.github/workflows/    Release workflow (runs on every push to master).
```

Use `@ViewState` for view-owned state. It aliases SwiftUI's `State` property wrapper, avoiding the SwiftUI macro plugin missing from the macOS 27 Command Line Tools.

To add a tool, create a folder under `Modules/`, add its config struct to `TookiKit/Config.swift`, wire it in `AppController`, and add a page to `SettingsPage`.

See [MODERNIZATION.md](MODERNIZATION.md) for module boundaries, the Clipboard reference migration, baseline measurements and following milestones. New shared UI belongs in `TookiDesignSystem`; feature logic must not depend on the native application target.

## UI component names

`design/ui-component-names-sketch.fig` names every part of the UI (Root Search, Actions Menu, Filter Menu, List-Detail Panel, Shelf Header and so on) with its Swift type. Use those names when you talk about the UI. When you add, rename or remove a component, update the sketch in the same change: edit it in [OpenPencil](https://openpencil.dev) and save. It's a rough sketch, so only the names, pins and notes need to be right. [AGENTS.md](../AGENTS.md) lists when to update it.

See [RELEASING.md](RELEASING.md) for how releases are published.
