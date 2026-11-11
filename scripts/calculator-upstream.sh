#!/usr/bin/env bash
# Lists Asyar calculator commits and changed files since the commit pinned in docs/CALCULATOR.md.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
upstream_url="https://github.com/Xoshbin/asyar"
crate_path="asyar-launcher/src-tauri/crates/asyar-calculator"

pinned_hash="$(sed -n 's/^Pinned commit: \([0-9a-f]\{40\}\)$/\1/p' "$repo_root/docs/CALCULATOR.md")"
if [ -z "$pinned_hash" ]; then
    echo "error: no 'Pinned commit: <hash>' line in docs/CALCULATOR.md" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

echo "Cloning $upstream_url ..."
git clone --quiet --filter=blob:none "$upstream_url" "$work_dir/asyar"

echo
echo "Commits touching $crate_path since ${pinned_hash:0:7}:"
git -C "$work_dir/asyar" --no-pager log --oneline "$pinned_hash..HEAD" -- "$crate_path"

echo
echo "Diffstat:"
git -C "$work_dir/asyar" --no-pager diff --stat "$pinned_hash..HEAD" -- "$crate_path"
