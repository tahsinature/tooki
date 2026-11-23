#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo 'Native toast verification requires macOS.'
  exit 1
fi
binary=$(mktemp /tmp/tooki-toast-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/toast_test.m \
  -framework AppKit -framework Foundation -o "$binary"
"$binary"
