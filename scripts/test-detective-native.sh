#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
  echo "Native callback checks require macOS. Run make test-detective for the portable tests."
  exit 1
fi
binary=$(mktemp -t tooki-detective-tests)
trap 'rm -f "$binary"' EXIT INT TERM
clang -fobjc-arc -Wall -Wextra src-tauri/crates/shortcut-detective/tests/macos_events.m -framework AppKit -framework ApplicationServices -o "$binary"
"$binary"
