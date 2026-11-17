#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
  echo 'The native instance guard test requires macOS.' >&2
  exit 1
fi
output=$(mktemp -d "${TMPDIR:-/tmp}/tooki-guard-test.XXXXXX")
trap 'rm -rf "$output"' EXIT HUP INT TERM
xcrun clang -fobjc-arc -fblocks src-tauri/native/instance_guard_tests.m -framework AppKit -o "$output/test"
"$output/test"
