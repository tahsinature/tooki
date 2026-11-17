# Developing Tooki

Tooki's primary application is the Rust/Tauri desktop app at the repository root. The previous Swift implementation is preserved, including its tests and build tooling, in `.playground/tooki-swift/` for migration reference. It is not part of the production build.

## Build and run

Use Bun 1.4.2 and current stable Rust. macOS builds need Xcode Command Line Tools or Xcode. The macOS app supports macOS 14 and later. Production packaging builds Apple Silicon and Intel into one app.

```sh
bun install --frozen-lockfile
make dev
make test
make app CONFIGURATION=debug
make dmg
```

`make dev` signs the executable with the local `Tooki Dev Signing` identity. Set `APPLE_SIGNING_IDENTITY` to another existing identity when needed. Release CI uses the existing `Tooki Release Signing` certificate. Development builds show the DEV menu-bar mark; release builds use the standard Tooki mark.

`make app` produces `build/Tooki.app`. `make dmg` produces `build/Tooki.dmg`. Set `VERSION`, `BUILD_NUMBER`, and `TAURI_TARGET=universal-apple-darwin` for a versioned universal bundle. Install both Rust targets first:

```sh
rustup target add aarch64-apple-darwin x86_64-apple-darwin
TAURI_TARGET=universal-apple-darwin make dmg
```

`make clean` stops development processes without deleting data or build caches. Stop builds before `make clean-builds`, which removes local generated build output. `make -C prototypes/desktop dev` remains a compatibility wrapper for earlier local workflows.

## Layout

- `src/`: Svelte/TypeScript interface, shared components, themes, and feature views.
- `src-tauri/src/`: Rust feature services, storage, commands, and platform boundaries.
- `src-tauri/native/`: Objective-C adapters for native macOS behavior.
- `src-tauri/crates/`: Hyper Key and Shortcut Detective support crates.
- `src-tauri/emoji/`: bundled emojibase catalog, filtered for macOS font support at runtime.
- `scripts/`: build, release versioning, and focused native checks.
- `packaging/tooki.rb`: Homebrew cask template published by CI.
- `.playground/tooki-swift/`: archived Swift sources and validation tools.

## Verification

`make test` runs Svelte diagnostics, TypeScript tests, Rust feature tests, and the support-crate tests. Native checks are available through `make test-clipboard-native`, `make test-detective-native`, `make test-hyper-native`, and `make test-preview-native`. They use isolated native inputs or pasteboards.

Also verify Root Search, settings, shared menus, Escape, completed-action dismissal, and the affected feature in the actual macOS app. Paste and automatic expansion need Accessibility; some automation tools bypass global keyboard events, so do not treat simulated input as proof of a real global shortcut.

## Data

The production bundle identifier is `us.tahsin.tooki`. Portable settings, shortcuts, themes and snippets live in `~/.config/tooki/`; machine-specific data stays in Tauri's application-data/config directories. See [Portable configuration](PORTABLE_CONFIGURATION.md) for migration and sync behavior. The old preview identifier was `us.tahsin.tooki.preview`. Original Swift files remain untouched; the Swift snippet library is copied once into the new format. Shelferry owns its own shelf windows and storage.

See [MIGRATION.md](MIGRATION.md), [SNIPPETS_DESKTOP.md](SNIPPETS_DESKTOP.md), and [RELEASING.md](RELEASING.md).
