#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo 'Native clipboard verification requires macOS.'
  exit 1
fi
binary=$(mktemp /tmp/tooki-clipboard-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/clipboard_test.m src-tauri/native/preview.m src-tauri/native/image_preview.m \
  -framework AppKit -framework Foundation -framework Vision \
  -framework Quartz -framework ApplicationServices -framework ImageIO -o "$binary"
"$binary"
