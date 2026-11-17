#!/usr/bin/env python3
"""Regenerate the bundled catalog using a pinned emojibase-data version."""
import json
from pathlib import Path
import sys
import urllib.request

version = sys.argv[1] if len(sys.argv) > 1 else '18.0.0'
base = f'https://cdn.jsdelivr.net/npm/emojibase-data@{version}'
def fetch(path):
    with urllib.request.urlopen(f'{base}/{path}') as response:
        return json.load(response)

emoji = fetch('en/compact.json')
shortcodes = fetch('en/shortcodes/github.json')
groups = sorted(fetch('en/messages.json')['groups'], key=lambda group: group['order'])
group_index = {group['order']: index for index, group in enumerate(group for group in groups if group['key'] != 'component')}
def clean(words):
    return ','.join(word.replace(',', ' ').replace('\t', ' ').replace('\n', ' ').strip() for word in words)

lines = []
for item in sorted(emoji, key=lambda item: item.get('order', 1 << 30)):
    if item.get('group') not in group_index:
        continue
    codes = shortcodes.get(item['hexcode'], [])
    fields = [item['unicode'], item['label'].lower(), str(group_index[item['group']]), clean(item.get('tags', [])), clean([codes] if isinstance(codes, str) else codes)]
    lines.append('\t'.join(fields))
destination = Path(__file__).resolve().parent.parent / 'src-tauri/emoji/catalog.tsv'
destination.write_text('\n'.join(lines) + '\n')
print(f'Wrote {len(lines)} emoji from emojibase-data {version}. Review catalog group names when upgrading.')
