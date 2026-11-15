#!/usr/bin/env bash
# Preserve Sparkle's versioned symlinks, permissions and helper entitlements.
set -euo pipefail
source_framework="$1"
app="$2"
identity="$3"
framework="$app/Contents/Frameworks/Sparkle.framework"
[[ -d "$source_framework" ]] || { echo "Sparkle.framework is missing from the Swift build products." >&2; exit 1; }
mkdir -p "$app/Contents/Frameworks"
ditto "$source_framework" "$framework"
# Sign inside out. Do not use --deep to guess the signing order.
codesign --force --sign "$identity" --preserve-metadata=entitlements "$framework/Versions/B/Autoupdate"
codesign --force --sign "$identity" --preserve-metadata=entitlements "$framework/Versions/B/Updater.app"
codesign --force --sign "$identity" --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign "$identity" --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign "$identity" "$framework"
