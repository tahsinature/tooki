#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
config="$(mktemp /tmp/tooki-bundle.XXXXXX)"
trap 'rm -f "$config"' EXIT
python3 - "$config" <<'PY'
import json, os, sys
base = json.load(open('src-tauri/tauri.conf.json'))
mac = {'signingIdentity': os.environ.get('APPLE_SIGNING_IDENTITY', 'Tooki Dev Signing')}
if os.environ.get('BUILD_NUMBER'):
    mac['bundleVersion'] = os.environ['BUILD_NUMBER']
json.dump({'version': os.environ.get('VERSION', base['version']), 'bundle': {'active': True, 'macOS': mac}}, open(sys.argv[1], 'w'))
PY
args=(build --bundles app --config "$config")
profile=release
if [[ "${CONFIGURATION:-release}" == debug ]]; then args+=(--debug); profile=debug; fi
output="src-tauri/target/$profile"
if [[ -n "${TAURI_TARGET:-}" ]]; then
  args+=(--target "$TAURI_TARGET")
  output="src-tauri/target/$TAURI_TARGET/$profile"
fi
bun run tauri "${args[@]}"
codesign --verify --deep --strict "$output/bundle/macos/Tooki.app"
mkdir -p build
ditto "$output/bundle/macos/Tooki.app" build/Tooki.app
if [[ "${1:-app}" == dmg ]]; then
  staging="$(mktemp -d /tmp/tooki-dmg.XXXXXX)"
  trap 'rm -f "$config"; rm -rf "$staging"' EXIT
  ditto build/Tooki.app "$staging/Tooki.app"
  ln -s /Applications "$staging/Applications"
  hdiutil create -volname Tooki -srcfolder "$staging" -ov -format UDZO build/Tooki.dmg
fi
