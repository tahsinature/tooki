# Releasing Tooki

The Release workflow publishes the primary Rust/Tauri application. A push to `master` chooses the next version from commit messages, runs `make test`, builds a universal macOS app, signs it with the existing release certificate, publishes `Tooki.dmg` and a signed updater archive, and updates `tahsinature/homebrew-tap`.

## Install and update

```sh
brew install --cask tahsinature/tap/tooki
brew update
brew reinstall --cask tahsinature/tap/tooki
```

Homebrew 7 or later may require `brew trust tahsinature/tap` once. The cask installs `/Applications/Tooki.app`, identifier `us.tahsin.tooki`, for macOS 14 or later. The DMG contains both Apple Silicon and Intel executables. Updates can be installed in Settings → About or with `brew upgrade --cask --greedy tooki`. Homebrew skips self-updating casks during ordinary upgrades. `brew reinstall --cask tahsinature/tap/tooki` always remains available.

Production macOS builds support Tauri’s signed updater. Older Tauri builds need one final Homebrew reinstall to gain it. Development builds only check release availability and cannot install production updates. The cask declares `auto_updates`. Each Tauri release retains the unchanged v0.11.0 Sparkle appcast for existing Swift installations; this keeps their feed valid without advertising an incompatible in-app transition. Use Homebrew or the DMG to switch from Swift.

Existing Swift settings, snippets, clipboard history and shelf files are preserved. They are not automatically imported into Tauri.

## Version and workflow

`scripts/next-version.sh` uses the latest published `v*` tag. `feat:` selects a minor bump, a conventional breaking-change marker selects major, and other commits select patch. The workflow can also be dispatched with an explicit bump. Do not create version tags manually; the release creates its tag at the tested commit.

`scripts/package-macos.sh` accepts `VERSION`, `BUILD_NUMBER`, `APPLE_SIGNING_IDENTITY`, `TAURI_TARGET`, and `CONFIGURATION`, and `TOOKI_BUILD_TIMESTAMP` (Unix seconds). Packaging embeds the build instant once for both architectures; local Cargo builds use their compilation time. CI sets the build number to its increasing run number. The build checks the bundle identity, version, signature, and both architectures before publication. Packaging defaults `CARGO_PROFILE_RELEASE_STRIP=none` to avoid Rust/LLVM issue [157750](https://github.com/rust-lang/rust/issues/157750), which produces macro libraries rejected by macOS 27. Remove that default after the supported toolchain fixes the issue and a clean universal build passes.

CI uses Bun 1.4.2, stable Rust with both macOS targets, and the existing Xcode runner. Cargo dependencies and frontend dependencies use committed lockfiles. Source changes, including the Swift archive, are versioned together; generated output is ignored.

## Existing secrets

- `SIGNING_CERT_P12` and `SIGNING_CERT_PASSWORD`: the stable Tooki release signing identity. Keep it stable to preserve macOS app recognition across updates.
- `HOMEBREW_TAP_TOKEN`: Contents read/write access to the tap. A missing token fails publication of the cask rather than reporting success.
- `TAURI_SIGNING_PRIVATE_KEY`: Tauri updater private key. Required for release packaging. Its public key is embedded in `src-tauri/tauri.conf.json`. Never regenerate it casually: existing installations trust that key.
- `TAURI_SIGNING_PRIVATE_KEY_PASSWORD`: optional password for an encrypted updater key.
- `SPARKLE_PRIVATE_KEY`: retained for the archived Swift app; the Tauri workflow does not export or use it.

The existing distribution remains self-signed and not notarized. Homebrew retains its existing quarantine handling. This transition does not claim Developer ID signing or notarization.

The source cask is `packaging/tooki.rb`; CI replaces its version and SHA-256 when publishing to `Casks/tooki.rb` in the tap. Verify that the public cask version and checksum match the release asset before reporting a release complete.

## Signed in-app updates

Settings → About → Check for Updates queries GitHub’s latest stable release. Update & Restart is available when the release includes `latest.json`, `Tooki.app.tar.gz`, and `Tooki.app.tar.gz.sig`. The existing Homebrew command is retained under a disclosure for older releases and manual updates.

The Rust service pins the chosen version, fetches its versioned manifest, checks the expected artifact URL, downloads asynchronously, verifies its signature and signed version (`requireSignedVersion`), installs through the official Tauri updater, and requests a normal restart. All existing exit hooks save state and release the instance lock before relaunch. Download, signature, and installation failures stay visible and allow retry. An installation into a protected Applications directory may trigger macOS administrator authorization.

Only packaged production macOS apps can install. Development identities, debug executables, disk-image launches, older/equal versions and prereleases are rejected in Rust. No arbitrary URLs, paths, commands or signing keys are accepted from the frontend. The frontend has no direct updater-plugin permissions.

CI sets `TOOKI_UPDATER_ARTIFACTS=1`, signs the archive through Tauri’s bundler, verifies it against the embedded public key and release version with the `verify_update` example, and runs `scripts/updater-manifest.py` to produce a static manifest with both `darwin-aarch64` and `darwin-x86_64` pointing to the same universal package. The archive, signature, manifest and DMG are published together. Normal local builds do not require the release key. For a signed local package, set `VERSION`, `TAURI_TARGET=universal-apple-darwin`, `TOOKI_UPDATER_ARTIFACTS=1`, and `TAURI_SIGNING_PRIVATE_KEY` to a protected private-key file before `make dmg`.

The initial key backup is stored outside the repository at `~/.local/share/tooki-release/updater.key`, with owner-only permissions. Back it up securely; do not put it in the synced Tooki configuration or source control. The GitHub secret holds the same key for CI. The updater key is separate from the macOS code-signing certificate and the archived Sparkle key.

The existing distribution remains self-signed; updater signature verification does not imply Developer ID signing or Apple notarization. The updater replaces only the app bundle, leaving configuration and application data in their existing locations.
