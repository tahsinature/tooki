import { existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { gzipSync } from 'node:zlib';

const root = resolve(import.meta.dir, '..');

function filesIn(directory: string): string[] {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return filesIn(path);
    return entry.isFile() ? [path] : [];
  });
}

function format(bytes: number): string {
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  const index = bytes ? Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), 3) : 0;
  return `${(bytes / 1024 ** index).toFixed(index ? 2 : 0)} ${units[index]}`;
}

function report(label: string, bytes: number): void {
  console.log(`${label.padEnd(52)} ${format(bytes).padStart(12)}`);
}

function reportArtifact(path: string): void {
  const label = relative(root, path);
  if (!existsSync(path)) {
    console.log(`${label.padEnd(52)}    not built`);
    return;
  }
  const info = statSync(path);
  const bytes = info.isDirectory()
    ? filesIn(path).reduce((total, file) => total + statSync(file).size, 0)
    : info.size;
  report(label, bytes);
}

console.log('Tooki • existing build sizes\n');
const assets = filesIn(join(root, 'dist'));
if (assets.length) {
  let total = 0;
  let compressed = 0;
  for (const path of assets) {
    const bytes = await Bun.file(path).bytes();
    report(relative(root, path), bytes.length);
    total += bytes.length;
    compressed += gzipSync(bytes).length;
  }
  report('Frontend total', total);
  report('Frontend gzip estimate (files compressed separately)', compressed);
} else {
  console.log('Frontend: not built. Run bun run build.');
}

console.log('\nNative executables');
const target = process.env.CARGO_TARGET_DIR
  ? resolve(root, process.env.CARGO_TARGET_DIR)
  : join(root, 'src-tauri/target');
const executable = process.platform === 'win32' ? 'tooki.exe' : 'tooki';
for (const profile of ['debug', 'release']) {
  reportArtifact(join(target, profile, executable));
}

console.log('\nPackaged applications / installers');
let packages = 0;
function reportPackages(directory: string): void {
  if (!existsSync(directory)) return;
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (/\.(app|dmg|deb|rpm|AppImage|msi|exe|zip|gz)$/.test(entry.name)) {
      reportArtifact(path);
      packages++;
    } else if (entry.isDirectory()) {
      reportPackages(path);
    }
  }
}
for (const profile of ['debug', 'release']) reportPackages(join(target, profile, 'bundle'));
if (!packages) console.log('None built. Packaging is currently disabled in the prototype.');
console.log('\nLogical file sizes, excluding caches and dependencies. Existing artifacts may be stale.');
console.log('Gzip is a web transfer estimate, not the native app size. Debug is not release size.');
console.log('The release executable embeds the frontend; do not add their sizes together.');
