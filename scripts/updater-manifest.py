#!/usr/bin/env python3
"""Publish one signed universal macOS package for both supported architectures."""
import datetime
import json
from pathlib import Path
import re
import sys


def create_manifest(version: str, directory: Path) -> dict:
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
        raise ValueError('Expected a stable MAJOR.MINOR.PATCH version')
    archive = directory / 'Tooki.app.tar.gz'
    signature = directory / 'Tooki.app.tar.gz.sig'
    if not archive.is_file() or archive.stat().st_size == 0:
        raise ValueError('Missing updater archive')
    signed = signature.read_text().strip()
    if not signed:
        raise ValueError('Missing updater signature')
    package = {
        'url': f'https://github.com/tahsinature/tooki/releases/download/v{version}/{archive.name}',
        'signature': signed,
    }
    return {
        'version': version,
        'pub_date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'notes': f'Tooki {version}. Release notes: https://github.com/tahsinature/tooki/releases/tag/v{version}',
        'platforms': {target: package for target in ('darwin-aarch64', 'darwin-x86_64')},
    }


if __name__ == '__main__':
    version, output_directory = sys.argv[1:]
    directory = Path(output_directory)
    manifest = create_manifest(version, directory)
    (directory / 'latest.json').write_text(json.dumps(manifest, indent=2) + '\n')
