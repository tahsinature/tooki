#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo 'Expected a Cargo executable and optional application arguments.' >&2
  exit 2
fi

# Cargo also uses runners for tests and examples. Only sign the application.
if [[ "$(basename "$1")" == tooki ]]; then
  # Keep the identifier aligned with tauri.dev.conf.json.
  # Tauri's bundler supports the same identity override.
  identity="${APPLE_SIGNING_IDENTITY:-Tooki Dev Signing}"
  echo "Signing Tooki development executable with: $identity" >&2
  codesign --force --sign "$identity" --identifier us.tahsin.tooki.dev "$1"
  codesign --verify --strict "$1"
fi

exec "$@"
