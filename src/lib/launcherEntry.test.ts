import { expect, test } from 'bun:test';
import { enterLauncher, toolEntry } from './launcherEntry';

test('launcher shortcut resumes without resetting search, selection or scroll', async () => {
  const state = {
    tool: 'clipboard',
    query: 'invoice',
    selection: 32,
    scroll: 860,
  };
  const original = { ...state };
  const unexpected = () => {
    throw new Error('Resume must not remount the tool');
  };
  expect(
    await enterLauncher(
      { mode: 'resume', target: null },
      unexpected,
      async () => unexpected(),
      unexpected,
      () => true,
    ),
  ).toBe(true);
  expect(state).toEqual(original);
});

test('dedicated tool entry unmounts first, even when reopening the same tool', async () => {
  const events: string[] = [];
  await enterLauncher(
    { mode: 'fresh', target: 'command:clipboard.open' },
    () => events.push('reset'),
    async () => {
      events.push('unmounted');
    },
    (target) => events.push(target),
    () => true,
  );
  expect(events).toEqual(['reset', 'unmounted', 'command:clipboard.open']);
});

test('fresh root and superseded requests cannot restore an old tool', async () => {
  let current = true;
  const events: string[] = [];
  await enterLauncher(
    { mode: 'fresh', target: null },
    () => events.push('root'),
    async () => {},
    () => events.push('tool'),
    () => current,
  );
  expect(events).toEqual(['root']);
  const applied = await enterLauncher(
    { mode: 'fresh', target: 'command:emoji.open' },
    () => {},
    async () => {
      current = false;
    },
    () => events.push('stale'),
    () => current,
  );
  expect(applied).toBe(false);
  expect(events).toEqual(['root']);
});

test('all embedded tools use fresh defaults while specialized clipboard commands keep their filter', () => {
  for (const [target, view, filter] of [
    ['clipboard.open', 'clipboard', 'all'],
    ['clipboard.pinned', 'clipboard', 'pinned'],
    ['clipboard.links', 'clipboard', 'link'],
    ['snippets.open', 'snippets', 'all'],
    ['emoji.open', 'emoji', 'all'],
    ['systemMonitor.open', 'systemMonitor', 'all'],
    ['system.open', 'system', 'all'],
    ['system.eject', 'system', 'all'],
    ['system.emptyTrash', 'system', 'all'],
    ['keepAwake.open', 'system', 'all'],
  ] as const)
    expect(toolEntry(`command:${target}`)).toEqual({ view, filter });
  expect(() => toolEntry('command:unknown')).toThrow();
});
