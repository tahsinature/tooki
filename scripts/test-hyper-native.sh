#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
  echo 'The native mapping parser test requires macOS.' >&2
  exit 1
fi
output=$(mktemp -d "${TMPDIR:-/tmp}/tooki-hyper-test.XXXXXX")
trap 'rm -rf "$output"' EXIT HUP INT TERM
xcrun clang -fobjc-arc -fblocks src-tauri/native/hyper_tests.m -framework AppKit -framework ApplicationServices -framework IOKit -o "$output/test"
"$output/test"
