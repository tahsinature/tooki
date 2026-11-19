import { expect, test } from 'bun:test';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

test('release manifest uses the same versioned signed package for both Mac architectures', () => {
  const directory = mkdtempSync(join(tmpdir(), 'tooki-update-manifest-'));
  const script = resolve(import.meta.dir, 'updater-manifest.py');
  const run = (version: string) =>
    Bun.spawnSync(['python3', script, version, directory]);
  try {
    expect(run('1.2.3').exitCode).not.toBe(0);
    writeFileSync(join(directory, 'Tooki.app.tar.gz'), 'fixture archive');
    writeFileSync(
      join(directory, 'Tooki.app.tar.gz.sig'),
      'fixture-signature\n',
    );
    for (const invalid of ['../other', '1.2.3-beta.1', 'v1.2.3', '01.2.3']) {
      expect(run(invalid).exitCode).not.toBe(0);
    }
    expect(run('1.2.3').exitCode).toBe(0);
    const manifest = JSON.parse(
      readFileSync(join(directory, 'latest.json'), 'utf8'),
    );
    expect(manifest.version).toBe('1.2.3');
    expect(Object.keys(manifest.platforms).sort()).toEqual([
      'darwin-aarch64',
      'darwin-x86_64',
    ]);
    expect(manifest.platforms['darwin-aarch64']).toEqual(
      manifest.platforms['darwin-x86_64'],
    );
    expect(manifest.platforms['darwin-aarch64']).toEqual({
      url: 'https://github.com/tahsinature/tooki/releases/download/v1.2.3/Tooki.app.tar.gz',
      signature: 'fixture-signature',
    });
    writeFileSync(join(directory, 'Tooki.app.tar.gz.sig'), '');
    expect(run('1.2.3').exitCode).not.toBe(0);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
