#!/usr/bin/env bash
# Use Sparkle's generator and signer rather than assembling update XML ourselves.
set -euo pipefail
archives="$1"
download_prefix="$2"
tools="${SPARKLE_TOOLS_DIR:-.build/artifacts/sparkle/Sparkle/bin}"
[[ "$download_prefix" == https://* ]] || { echo "Release download URLs must use HTTPS." >&2; exit 1; }
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    # A GitHub Actions secret enters through stdin, never arguments or a repository file.
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tools/generate_appcast" --ed-key-file - --download-url-prefix "$download_prefix" "$archives"
else
    "$tools/generate_appcast" --account us.tahsin.tooki --download-url-prefix "$download_prefix" "$archives"
fi
