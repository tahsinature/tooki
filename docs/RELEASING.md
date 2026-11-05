# Releasing Tooki

Releases are automatic. Every push to `master` builds Tooki, publishes a GitHub release and updates the Homebrew cask. There is nothing to run by hand.

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

1. **Pick the version** with `scripts/next-version.sh`. If there are no new commits, every later step is skipped.
2. **Test** with `make test`. A failing test stops the release.
3. **Build** a universal (Apple Silicon and Intel) DMG with `make dmg`, stamping the version into the app.
4. **Publish** the GitHub release `vX.Y.Z` with the DMG attached. Creating the release also creates the tag. The notes list the commit subjects since the previous release.
5. **Update Homebrew** by copying `packaging/tooki.rb` into the tap repository with the new `version` and `sha256` filled in.

Releases run one at a time in push order, so two quick pushes never claim the same version.

## Releasing on demand

To release without a new commit, or to force a bump type, open **Actions → Release → Run workflow** and choose `auto`, `patch`, `minor` or `major`. With `auto` and no new commits, the run does nothing.

## Homebrew

Users install with:

```sh
brew install --cask tahsinature/tap/tooki
```

The cask lives in [tahsinature/homebrew-tap](https://github.com/tahsinature/homebrew-tap) at `Casks/tooki.rb`. Its source of truth is `packaging/tooki.rb` in this repository. Edit that file, not the tap, because the workflow overwrites the tap copy on every release. The `version` and `sha256` lines in `packaging/tooki.rb` are replaced by the workflow on each release.

The workflow pushes to the tap with the `HOMEBREW_TAP_TOKEN` repository secret. This is a fine-grained personal access token named `tooki-homebrew-tap`, limited to the tap repository with **Contents: Read and write**. If the secret is missing, the release still happens and the workflow logs a warning instead of updating the cask.

### Replacing the token

If the token is revoked or leaked:

1. Delete it at GitHub → Settings → Developer settings → Fine-grained tokens.
2. Create a new one: resource owner `tahsinature`, only the `homebrew-tap` repository, Contents read and write.
3. Save it: `gh secret set HOMEBREW_TAP_TOKEN -R tahsinature/tooki` and paste the token.

## Things to know

- **The app is not notarized.** It is signed ad hoc (`SIGN_ID=-`). The cask removes the quarantine flag after install so the app opens. People who download the DMG directly have to right-click → Open the first time.
- **Local builds show the version from `Resources/Info.plist`.** Only release builds get the real version number. You do not need to edit `Info.plist` when releasing.
- **Do not create `v*` tags by hand.** The workflow treats the latest tag as the last release, so a manual tag changes the next version number.
- **A broken release** can be removed with `gh release delete vX.Y.Z --cleanup-tag`. Then push a fix. If the cask was already updated, the next successful release overwrites it.
