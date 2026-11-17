# Updater evaluation

November 15, 2026.

## Recommendation

Use Sparkle 2 for the next updater integration. It provides a supported programmatic/SwiftUI setup and an established update-distribution workflow. See the [official setup](https://sparkle-project.org/documentation/) and [programmatic integration guide](https://sparkle-project.org/documentation/programmatic-setup/).

The alternatives are to retain the current custom installer or rely on external package-manager updates. Retaining it has the smallest immediate cost but keeps download, installation, rollback and release compatibility work in Tooki. External-only updating would remove the current in-app update experience. Sparkle is the preferred balance for this app.

## Current Tooki integration points

- `Updater` reads GitHub's latest-release JSON and schedules daily checks.
- `UpdateInstaller` downloads a DMG, verifies the running app's designated signing requirement and starts a shell-based replacement/rollback process.
- The release workflow publishes a DMG and Homebrew metadata. It does not publish a Sparkle feed.
- `Resources/Info.plist` has `CFBundleVersion` fixed at `1`.
- The Makefile currently copies resource bundles and signs the outer app; it does not embed Sparkle's framework/helpers.
- Release signing supports a stable custom identity and an ad-hoc fallback. This must be evaluated with the chosen Sparkle packaging/signing configuration rather than assumed compatible.

## Concrete integration plan

1. Choose the feed URL and signing-key custody. Sparkle uses an appcast and an embedded public update-signing key. Its documentation describes EdDSA signing and feed generation. [Distribution requirements](https://sparkle-project.org/documentation/).
2. Pin a reviewed Sparkle 2 release through Swift Package Manager. Add framework/helper embedding and signing to Tooki's Makefile, preserving the required bundle structure and permissions. [Packaging requirements](https://sparkle-project.org/documentation/).
3. Generate a monotonic release build number instead of the fixed `CFBundleVersion`. Publish the signed appcast alongside release artifacts. [Version and feed requirements](https://sparkle-project.org/documentation/).
4. Replace the native updater adapter with a programmatic Sparkle controller. Retain development-build isolation and connect About/menu controls to the supported API. Map application-specific update presentation through an adapter rather than duplicating an installer.
5. Test an isolated older/newer app pair, manual/automatic checking, declined updates, invalid signatures, installation failure and restart. Keep the existing installer until the replacement passes its complete release-path test.
6. Remove superseded installer code, update third-party notices and document the release procedure.

## Decision status

The original evaluation is complete. Integration was subsequently approved: Sparkle 2.10.1, its standard update window, a Keychain-held signing key and GitHub Releases appcast hosting. See RELEASING.md for the implemented pipeline and the completed authorized private-key upload and release verification requirements. No public release or update of the installed Tooki app is performed by this migration.
