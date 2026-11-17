# Releasing Tooki

The Release workflow publishes the primary Rust/Tauri application. A push to `master` chooses the next version from commit messages, runs `make test`, builds a universal macOS app, signs it with the existing release certificate, publishes `Tooki.dmg`, and updates `tahsinature/homebrew-tap`.

## Install and update

```sh
brew install --cask tahsinature/tap/tooki
brew update
brew reinstall --cask tahsinature/tap/tooki
```

Homebrew 7 or later may require `brew trust tahsinature/tap` once. The cask installs `/Applications/Tooki.app`, identifier `us.tahsin.tooki`, for macOS 14 or later. The DMG contains both Apple Silicon and Intel executables. Ordinary updates use `brew upgrade --cask tooki`.

The Tauri version does not yet include an in-app updater. The cask no longer declares `auto_updates`, so Homebrew can offer updates normally. Each Tauri release retains the unchanged v0.11.0 Sparkle appcast for existing Swift installations; this keeps their feed valid without advertising an incompatible in-app transition. Use Homebrew or the DMG to switch from Swift.

Existing Swift settings, snippets, clipboard history and shelf files are preserved. They are not automatically imported into Tauri. Shelferry is a separate optional installation: `brew install --cask tahsinature/tap/shelferry`.

## Version and workflow

`scripts/next-version.sh` uses the latest published `v*` tag. `feat:` selects a minor bump, a conventional breaking-change marker selects major, and other commits select patch. The workflow can also be dispatched with an explicit bump. Do not create version tags manually; the release creates its tag at the tested commit.

`scripts/package-macos.sh` accepts `VERSION`, `BUILD_NUMBER`, `APPLE_SIGNING_IDENTITY`, `TAURI_TARGET`, and `CONFIGURATION`. CI sets the build number to its increasing run number. The build checks the bundle identity, version, signature, and both architectures before publication.

CI uses Bun 1.4.2, stable Rust with both macOS targets, and the existing Xcode runner. Cargo dependencies and frontend dependencies use committed lockfiles. Source changes, including the Swift archive, are versioned together; generated output is ignored.

## Existing secrets

- `SIGNING_CERT_P12` and `SIGNING_CERT_PASSWORD`: the stable Tooki release signing identity. Keep it stable to preserve macOS app recognition across updates.
- `HOMEBREW_TAP_TOKEN`: Contents read/write access to the tap. A missing token fails publication of the cask rather than reporting success.
- `SPARKLE_PRIVATE_KEY`: retained for the archived Swift app; the Tauri workflow does not export or use it.

The existing distribution remains self-signed and not notarized. Homebrew retains its existing quarantine handling. This transition does not claim Developer ID signing or notarization.

The source cask is `packaging/tooki.rb`; CI replaces its version and SHA-256 when publishing to `Casks/tooki.rb` in the tap. Verify that the public cask version and checksum match the release asset before reporting a release complete.

## In-app update checks

Settings → About → Check for Updates queries GitHub’s latest stable release when clicked. It compares semantic versions, opens release notes in the browser and offers `brew update && brew upgrade --cask tahsinature/tap/tooki` on macOS when a newer version is available. It does not install updates or run Homebrew automatically. Development builds newer than the published release are identified separately.

The checker uses the [GitHub latest-release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release), with bounded responses and request timeouts. Keep release tags in `vMAJOR.MINOR.PATCH` format. The Homebrew cask can briefly lag behind release publication while the workflow finishes.
