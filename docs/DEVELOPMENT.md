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

`make dev` signs the executable with the local `Tooki Dev Signing` identity. Set `APPLE_SIGNING_IDENTITY` to another existing identity when needed. Release CI uses the existing `Tooki Release Signing` certificate. Development builds show the DEV menu-bar mark and a DEV badge beside Tooki in the launcher footer; release builds use the standard Tooki mark.

`make app` produces `build/Tooki.app`; `make app CONFIGURATION=debug` produces `build/Tooki Dev.app`. `make dmg` produces `build/Tooki.dmg`. Set `VERSION`, `BUILD_NUMBER`, and `TAURI_TARGET=universal-apple-darwin` for a versioned universal bundle. Install both Rust targets first:

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

## Accessibility startup check

On macOS, both development and production builds check the running process’s Accessibility grant at startup. Missing access opens Tooki Settings with a shared setup dialog. Later dismisses it for that launch while a reminder remains in Settings. A grant or revocation is detected within two seconds and on returning to Settings; enabled Hyper Key and snippet expansion are refreshed. Blocked paste actions reopen the same setup flow. Copy and unrelated tools remain usable.

The dialog identifies the actual app path. macOS grants must be managed on each computer for the copy being run; they are never synced in Tooki configuration. Opening System Settings does not grant access. Verification must not change Accessibility permissions without the user’s approval. Non-macOS builds do not display this macOS-specific prompt.

## Development identity and launch guard

Use `make dev` (or `bun run desktop`) for live reload. This loads `src-tauri/tauri.dev.conf.json`: app name `Tooki Dev`, identifier `us.tahsin.tooki.dev`, and URL scheme `tooki-dev`. Debug bundles use the same identity. Production retains `Tooki`, `us.tahsin.tooki`, and its existing URL schemes. Direct debug launches without this configuration are rejected to avoid borrowing the production identity.

On macOS, dev startup requests a normal quit from the production app and waits up to eight seconds before creating any windows or starting its own services. If production refuses or remains running, dev aborts without a forced kill. A local process lock also prevents current dev/production builds from starting concurrently. Production startup refuses to run while dev is active. Older production releases do not have this reverse guard, so avoid manually reopening an older production app during development.

Each identity has separate local history, notes, window state and permissions. Neither local data directory is migrated or deleted. Both intentionally use the same `~/.config/tooki/` portable settings, snippets and themes. Grant Accessibility to `Tooki Dev` once for its stable development signing identity. Production’s permission remains separate.
