#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo 'Native windows verification requires macOS.'
  exit 1
fi
binary=$(mktemp /tmp/tooki-windows-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/windows_test.m \
  -framework AppKit -framework Foundation -o "$binary"
"$binary"
