import { expect, test } from 'bun:test';
import { commandItems } from './search';
import { commands } from '../../lib/data';
import { searchItems } from '../launcher/search';
const preferences = {
  'command:notes.open': { favorite: false, shortcut: '', alias: 'writing' },
  'command:notes.new': { favorite: false, shortcut: '', alias: 'draft' },
};
test('tool assignments preserve one root command per tool', () => {
  expect(commandItems('', preferences).map((item) => item.id)).toEqual(
    commands
      .filter(
        (item) =>
          !['system', 'keepAwake', 'systemMonitor'].includes(item.id),
      )
      .map((item) => item.id),
  );
  expect(
    Object.hasOwn(commandItems('', preferences).find((item) => item.id === 'notes')!, 'alias'),
  ).toBe(false);
});

test('wake lock search finds Keep Awake and Keep Awake aliases respect platform support', () => {
  const preferences = {
    'command:system.keepAwakeToggle': {
      favorite: false,
      shortcut: '',
      alias: 'awake',
    },
  };
  const support = {
    'command:keepAwake.open': { available: true },
    'command:system.keepAwakeToggle': { available: true },
  };
  expect(
    searchItems(commandItems('wake lock', {}, support), 'wake lock', 'all').map(
      (item) => item.id,
    ),
  ).toContain('keepAwake');
  expect(commandItems('awake', preferences, support).at(-1)?.id).toBe(
    'command:system.keepAwakeToggle',
  );
  expect(
    commandItems('awake', preferences, {}).some(
      (item) => item.id === 'command:system.keepAwakeToggle',
    ),
  ).toBe(false);
});
test('legacy aliases no longer expose commands', () => {
  expect(searchItems(commandItems(' DRAFT ', preferences), ' DRAFT ', 'all')).toEqual([]);
  expect(commandItems('dra', preferences)).toHaveLength(commands.length - 3);
  expect(commandItems('draft', {})).toHaveLength(commands.length - 3);
});

test('unsupported commands stay out of root search and title results', () => {
  const prefs = {
    'command:system.sleep': { favorite: false, shortcut: '', alias: 'nap' },
  };
  expect(
    commandItems('sleep', prefs).some(
      (item) => item.id === 'command:system.sleep',
    ),
  ).toBe(false);
  expect(
    commandItems('sleep', prefs, {
      'command:system.sleep': { available: true },
    }).at(-1)?.id,
  ).toBe('command:system.sleep');
  expect(
    commandItems('', prefs, {
      'command:system.open': { available: true },
    }).some((item) => item.id === 'system'),
  ).toBe(true);
  expect(
    commandItems('', prefs, {
      'command:system.open': { available: false, reason: 'Unsupported' },
    }).some((item) => item.id === 'system'),
  ).toBe(false);
});

test('System Monitor has one searchable root command and respects platform support', () => {
  const support = { 'command:systemMonitor.open': { available: true } };
  const matches = commandItems('', {}, support).filter(
    (item) => item.id === 'systemMonitor',
  );
  expect(matches).toHaveLength(1);
  expect(matches[0].content).toContain('cpu');
  expect(
    commandItems(
      '',
      {},
      { 'command:systemMonitor.open': { available: false } },
    ).some((item) => item.id === 'systemMonitor'),
  ).toBe(false);
});

test('trash search resolves directly to the Empty Trash command', () => {
  const support = {
    'command:system.open': { available: true },
    'command:system.emptyTrash': { available: true },
  };
  const results = searchItems(
    commandItems('trash', {}, support),
    'trash',
    'all',
  );
  expect(results.map((item) => item.id)).toEqual(['command:system.emptyTrash']);
  expect(results[0]).toMatchObject({
    title: 'Empty Trash',
    parentTitle: 'System Actions',
  });
});

test('matching actions share tool context, while direct tool matches remain', () => {
  const results = searchItems(commandItems('note', {}), 'note', 'all');
  expect(results.map((item) => item.id)).toContain('notes');
  expect(results.find((item) => item.id === 'command:notes.new')).toMatchObject(
    {
      title: 'New Note',
      parentTitle: 'Notes',
    },
  );
});

test('Keep Awake titles remain searchable while legacy aliases are ignored', () => {
  const id = 'command:system.keepAwake15';
  const support = {
    'command:keepAwake.open': { available: true },
    [id]: { available: true },
  };
  expect(
    commandItems('15 minutes', {}, support).find((item) => item.id === id),
  ).toMatchObject({
    parentTitle: 'Keep Awake',
    id,
  });
  const preferences = {
    [id]: { favorite: false, shortcut: '', alias: 'coffee' },
  };
  expect(
    commandItems('coffee', preferences, support).find((item) => item.id === id),
  ).toBeUndefined();
});

test('unavailable action titles never appear in search', () => {
  const support = {
    'command:system.open': { available: true },
    'command:system.emptyTrash': { available: false },
  };
  expect(
    commandItems('trash', {}, support).some(
      (item) => item.id === 'command:system.emptyTrash',
    ),
  ).toBe(false);
});
