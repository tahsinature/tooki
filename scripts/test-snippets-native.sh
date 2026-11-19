#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo 'Native snippet verification requires macOS.'
  exit 1
fi
binary=$(mktemp /tmp/tooki-snippets-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/snippets_test.m \
  -framework AppKit -framework ApplicationServices -framework Carbon -o "$binary"
"$binary"
