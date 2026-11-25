#!/bin/sh
set -eu
binary=$(mktemp /tmp/tooki-drop-content-test.XXXXXX)
trap 'rm -f "$binary"' EXIT
clang -fobjc-arc -fblocks src-tauri/native/drop_content_test.m \
  -framework AppKit -framework Foundation -framework QuickLookThumbnailing -o "$binary"
"$binary"
