import { resolve } from 'node:path';
const root = resolve(import.meta.dir, '..');
type Entry = { pid: number; parent: number; command: string };
function run(args: string[]): string {
  const result = Bun.spawnSync(args, { stdout: 'pipe', stderr: 'pipe' });
  return result.exitCode === 0 ? result.stdout.toString() : '';
}
function processes(): Entry[] {
  return run(['ps', '-axo', 'pid=,ppid=,command='])
    .split('\n')
    .flatMap((line) => {
      const match = line.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/);
      return match
        ? [
            {
              pid: Number(match[1]),
              parent: Number(match[2]),
              command: match[3],
            },
          ]
        : [];
    });
}
function cwd(pid: number): string {
  return (
    run(['lsof', '-a', '-p', String(pid), '-d', 'cwd', '-Fn'])
      .split('\n')
      .find((line) => line.startsWith('n'))
      ?.slice(1) ?? ''
  );
}
const snapshot = processes();
const protectedPids = new Set([process.pid]);
for (let pid = process.ppid; pid > 1;) {
  protectedPids.add(pid);
  pid = snapshot.find((entry) => entry.pid === pid)?.parent ?? 0;
}
const selected = new Set<number>();
for (const entry of snapshot) {
  if (protectedPids.has(entry.pid)) continue;
  const runner = /^(?:\S*\/)?(?:bun|node|cargo)(?:\s|$)/.test(entry.command);
  const dev =
    /(?:\bvite\b|\btauri(?:\.js)?\s+dev\b|\bcargo\s+run\b|\bbun\s+run\s+(?:desktop|dev|tauri)\b)/.test(
      entry.command,
    );
  const binary = /(?:^|\/)target\/debug\/tooki(?:\s|$)/.test(entry.command);
  const bundle = [
    resolve(root, 'build/Tooki Dev.app/Contents/MacOS/tooki'),
    resolve(
      root,
      'src-tauri/target/debug/bundle/macos/Tooki Dev.app/Contents/MacOS/tooki',
    ),
    '/Applications/Tooki Dev.app/Contents/MacOS/tooki',
  ].includes(entry.command);
  const verification =
    entry.command === '/private/tmp/Tooki.app/Contents/MacOS/tooki';
  if (
    bundle ||
    verification ||
    ((binary || (runner && dev)) &&
      [root, resolve(root, 'src-tauri')].includes(cwd(entry.pid)))
  )
    selected.add(entry.pid);
}
let changed = true;
while (changed) {
  changed = false;
  for (const entry of snapshot) {
    if (
      selected.has(entry.parent) &&
      !selected.has(entry.pid) &&
      !protectedPids.has(entry.pid)
    ) {
      selected.add(entry.pid);
      changed = true;
    }
  }
}
for (const pid of selected) {
  try {
    process.kill(pid, 'SIGTERM');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error;
  }
}
const deadline = Date.now() + 4000;
while (Date.now() < deadline && processes().some((p) => selected.has(p.pid)))
  await Bun.sleep(100);
const remaining = processes().filter((p) => selected.has(p.pid));
if (remaining.length) {
  console.error(
    `Tooki dev processes did not stop: ${remaining.map((p) => p.pid).join(', ')}. No forced kill was used.`,
  );
  process.exit(1);
}
const listener = run([
  'lsof',
  '-nP',
  '-iTCP:1421',
  '-sTCP:LISTEN',
  '-t',
]).trim();
if (listener) {
  console.error(
    `Port 1421 is still used by another process (${listener.replaceAll('\n', ', ')}). It was left untouched.`,
  );
  process.exit(1);
}
console.log(
  selected.size
    ? 'Stopped Tooki development processes. Port 1421 is free.'
    : 'No Tooki development processes are running.',
);
