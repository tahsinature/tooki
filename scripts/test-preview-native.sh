#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo 'Native Quick Look verification requires macOS.'
  exit 1
fi
binary=$(mktemp /tmp/tooki-preview-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/preview_test.m \
  -framework AppKit -framework Foundation -framework Quartz -o "$binary"
"$binary"
