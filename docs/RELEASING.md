# Releasing Tooki

Releases are automatic. Every push to `master` builds Tooki, publishes a GitHub release with a signed Sparkle appcast and updates the Homebrew cask. There is nothing to run by hand.

## Quick version

1. Write commit messages with a type prefix (see below).
2. Push to `master`.
3. Watch the **Release** workflow in the Actions tab. When it is green, users can run `brew upgrade --cask tooki`.

## How the version is chosen

`scripts/next-version.sh` reads the commit messages since the last `v*` tag and picks the bump:

| Commit message | Bump | Example |
| --- | --- | --- |
| `feat!: ...` (any type with `!`) or a body line starting with `BREAKING CHANGE:` | major | 1.4.2 → 2.0.0 |
| `feat: ...` or `feat(scope): ...` | minor | 1.4.2 → 1.5.0 |
| anything else (`fix:`, `chore:`, no prefix, ...) | patch | 1.4.2 → 1.4.3 |

The biggest bump wins. One `feat:` among ten `fix:` commits makes a minor release.

You can preview the next version locally:

```sh
scripts/next-version.sh          # what a push would release
scripts/next-version.sh minor    # force a bump type
```

It prints nothing when there are no commits since the last tag.

## What the workflow does

`.github/workflows/release.yml` runs these steps on a macOS runner:

The workflow uses GitHub's `xcode-27` image with Xcode 27.2 selected explicitly. Its macOS 27 environment matches the screenshot references and supports the required Swift 6.4 toolchain. GitHub currently labels this image as preview; availability and image updates should be monitored.

1. **Pick the version** with `scripts/next-version.sh`. If there are no new commits, every later step is skipped.
2. **Test** with `make test`. A failing test stops the release.
3. **Build** a universal (Apple Silicon and Intel) DMG with `make dmg`, stamping the version and increasing workflow run number into the app. Sparkle and its helpers are embedded and signed inside out before the app is signed.
4. **Generate the appcast** with Sparkle’s official `generate_appcast` tool and the `SPARKLE_PRIVATE_KEY` secret. This signs the update archive; a missing key stops the release.
5. **Publish** the GitHub release `vX.Y.Z` with the DMG and `appcast.xml` attached. Creating the release also creates the tag. The notes list the commit subjects since the previous release.
6. **Update Homebrew** by copying `packaging/tooki.rb` into the tap repository with the new `version` and `sha256` filled in.

Releases run one at a time in push order, so two quick pushes never claim the same version.

## Releasing on demand

To release without a new commit, or to force a bump type, open **Actions → Release → Run workflow** and choose `auto`, `patch`, `minor` or `major`. With `auto` and no new commits, the run does nothing.

## Homebrew

Users install with:

```sh
brew tap tahsinature/tap
brew trust tahsinature/tap    # Homebrew 7+ refuses casks from taps you have not trusted
brew install --cask tooki
```

The cask lives in [tahsinature/homebrew-tap](https://github.com/tahsinature/homebrew-tap) at `Casks/tooki.rb`. Its source of truth is `packaging/tooki.rb` in this repository. Edit that file, not the tap, because the workflow overwrites the tap copy on every release. The `version` and `sha256` lines in `packaging/tooki.rb` are replaced by the workflow on each release.

The workflow pushes to the tap with the `HOMEBREW_TAP_TOKEN` repository secret. This is a fine-grained personal access token named `tooki-homebrew-tap`, limited to the tap repository with **Contents: Read and write**. If the secret is missing, the release still happens and the workflow logs a warning instead of updating the cask.

### Replacing the token

If the token is revoked or leaked:

1. Delete it at GitHub → Settings → Developer settings → Fine-grained tokens.
2. Create a new one: resource owner `tahsinature`, only the `homebrew-tap` repository, Contents read and write.
3. Save it: `gh secret set HOMEBREW_TAP_TOKEN -R tahsinature/tooki` and paste the token.

## Things to know

- **The app is not notarized.** It is signed with a self-signed certificate, "Tooki Release Signing". The cask removes the quarantine flag after install so the app opens. People who download the DMG directly have to right-click → Open the first time.
- **The signing certificate keeps Accessibility across updates.** macOS remembers the permission for the certificate, not for one build. It lives in the `SIGNING_CERT_P12` (base64 .p12) and `SIGNING_CERT_PASSWORD` secrets. Keep a backup: a new certificate makes every user grant Accessibility once more. Without the secrets, the workflow falls back to ad hoc signing and warns.
- **Local builds show the version from `Resources/Info.plist`.** Only release builds get the real version number. You do not need to edit `Info.plist` when releasing.
- **Dev or release is shown at the bottom of the sidebar.** `make app` marks builds as `dev` with the git commit (the Tooki card shows an orange `Dev · abc1234`, with `•` for uncommitted changes). The workflow passes `CHANNEL=release`, so releases show `Version X.Y.Z` instead.
- **Do not create `v*` tags by hand.** The workflow treats the latest tag as the last release, so a manual tag changes the next version number.
- **A broken release** can be removed with `gh release delete vX.Y.Z --cleanup-tag`. Then push a fix. If the cask was already updated, the next successful release overwrites it.


## Sparkle update signing

Sparkle 2.10.1 is pinned in Package.swift. In-app updates use its standard window, download verification and installer. Development builds never start Sparkle. Users of the previous custom updater receive the first Sparkle-enabled version through the existing DMG update path or Homebrew.

The feed is `https://github.com/tahsinature/tooki/releases/latest/download/appcast.xml`. Each appcast points to the version-specific DMG asset. It contains the current complete update; historical archives and delta generation are not required for this initial setup.

The public Ed25519 key is embedded as `SUPublicEDKey` in Resources/Info.plist. Its private counterpart was generated in the login Keychain under account `us.tahsin.tooki`, using Sparkle’s `generate_keys`. Keep a secure backup. Do not regenerate it for each release or commit an exported private key. This key is separate from the existing application code-signing certificate; both identities must remain stable.

The private key has been uploaded, with authorization, as the encrypted GitHub Actions repository secret `SPARKLE_PRIVATE_KEY`. The temporary export was removed. To restore or transfer this setup later, use the procedure below. Use Sparkle’s `generate_keys --account us.tahsin.tooki -x <private-file>` to export it into a protected temporary file, upload through `gh secret set SPARKLE_PRIVATE_KEY --repo tahsinature/tooki < <private-file>`, then delete the temporary file. Run these commands only with authorization to export/upload the private key. The workflow passes the secret to `generate_appcast` through standard input, never a command argument or repository file.

Local feed generation uses the Keychain directly:

```sh
mkdir -p build/appcast
cp build/Tooki.dmg build/appcast/Tooki.dmg
scripts/generate-appcast.sh build/appcast https://github.com/tahsinature/tooki/releases/download/vX.Y.Z/
```

`CFBundleVersion` is the increasing GitHub Actions run number in releases. Local builds default to the Git commit count; set `BUILD_NUMBER` explicitly when testing older/newer pairs. Do not reset the release build sequence below already published values when moving the workflow.

The legacy JSON `updates.checkAutomatically` value seeds Sparkle’s preference once, on the first Sparkle-enabled launch. Subsequent changes in About or Sparkle’s window use Sparkle’s own persisted preference. Editing that legacy JSON field after migration does not overwrite the user’s current choice. The old `updateFeedURL` GitHub-JSON override and custom skipped-version preference are no longer used. Isolated test bundles can set Sparkle’s standard `SUFeedURL` override without changing the production feed.

The existing self-signed distribution and Homebrew quarantine handling remain in place. This migration does not add Developer ID signing, notarization, or publish a release. Production HTTPS hosting and the CI secret must be verified before shipping; local test-feed verification does not certify public distribution or Gatekeeper behavior.


## Migration verification (November 15, 2026)

- All 335 automated tests passed, including updater development-build isolation and error classification, native panel checks, and screenshot comparisons.
- A separate disposable application compiled the production `Updater` and `BuildInfo` sources. Its local feed delivered a correctly signed build 2 over build 1; Sparkle installed and relaunched it. The installed bundle passed strict nested-signature verification.
- An invalid archive signature was rejected before extraction; an HTTP 404 download showed Sparkle’s error UI. Both left build 1 unchanged. Skip persisted version 2, and a later manual check still offered it. Retrying the valid update successfully installed and relaunched build 2.
- `make dmg CONFIGURATION=debug CHANNEL=release` produced an isolated test DMG. The production appcast script generated the expected version-specific HTTPS enclosure, build number and archive size. CryptoKit independently verified the DMG’s Ed25519 signature against the public key embedded in Info.plist.
- Release YAML parsed, shell scripts passed syntax checks, and the packaged development and test-release apps passed strict nested-signature verification.

No public release, production feed fetch, production universal release build, permission-denied installation, Gatekeeper/notarization certification, or update of the user’s installed Tooki was performed. Those checks belong to the first controlled release, with the existing signing certificate retained. Temporary test bundles used their own identifier and defaults, a loopback-only server, and test-only HTTP transport settings; production uses HTTPS.
