# Developing Tooki

## Build from source

Requires macOS 14 or later and Swift 6. Apple's Command Line Tools (`xcode-select --install`) are enough. Full Xcode is not needed.

```sh
make test      # unit tests
make app       # builds and signs build/Tooki.app
make run       # builds and opens it, replacing any running copy
make install   # copies it to /Applications
make dmg       # builds build/Tooki.dmg
make info      # builds the app and shows its size, version, and requirements
make icon      # rebuilds Resources/AppIcon.icns after changing AppIcon.png (needs `brew install pngquant`)
```

The app is signed with your "Apple Development" certificate when you have one. A stable signature means macOS keeps the Accessibility permission across rebuilds. Without a certificate, the Makefile signs ad hoc, and you may need to grant Accessibility again after rebuilding. Override with `make app SIGN_ID="..."`.

Use `make dmg ARCHS="arm64 x86_64"` for a universal build (needs full Xcode).

## Project layout

```
Sources/TookiKit/     Logic without UI (config, placeholders, keyword matching). Unit tested.
Sources/Tooki/Core/   Event tap, synthetic keys, pasting, storage, panels.
Sources/Tooki/Modules One folder per module (controller + settings view).
Sources/Tooki/App/    App entry, wiring, settings window.
packaging/            Homebrew cask.
.github/workflows/    Release workflow (runs on every push to master).
```

Use `@ViewState` for view-owned state. It aliases SwiftUI's `State` property wrapper, avoiding the SwiftUI macro plugin missing from the macOS 27 Command Line Tools.

To add a tool, create a folder under `Modules/`, add its config struct to `TookiKit/Config.swift`, wire it in `AppController`, and add a page to `SettingsPage`.

See [RELEASING.md](RELEASING.md) for how releases are published.
