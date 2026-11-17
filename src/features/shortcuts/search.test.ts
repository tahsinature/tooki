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
      .filter((item) => !['system', 'keepAwake', 'shelf'].includes(item.id))
      .map((item) => item.id),
  );
  expect(
    commandItems('', preferences).find((item) => item.id === 'notes')?.alias,
  ).toBe('writing');
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
test('secondary commands appear only for exact aliases, including case and whitespace', () => {
  expect(commandItems(' DRAFT ', preferences).at(-1)?.id).toBe(
    'command:notes.new',
  );
  expect(commandItems('dra', preferences)).toHaveLength(commands.length - 3);
  expect(commandItems('draft', {})).toHaveLength(commands.length - 3);
});

test('unsupported commands stay out of root search and exact alias results', () => {
  const prefs = {
    'command:system.sleep': { favorite: false, shortcut: '', alias: 'nap' },
  };
  expect(
    commandItems('nap', prefs).some(
      (item) => item.id === 'command:system.sleep',
    ),
  ).toBe(false);
  expect(
    commandItems('nap', prefs, {
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

test('Shelferry availability gates root and alias routes without losing assignments', () => {
  const preferences = {
    'command:shelf.toggle': { favorite: false, shortcut: '', alias: 'shelves' },
  };
  const support = {
    'command:shelf.open': { available: true },
    'command:shelf.toggle': { available: true },
  };
  expect(
    commandItems('', {}, support).filter((item) => item.id === 'shelf'),
  ).toHaveLength(1);
  expect(commandItems('shelves', preferences, support).at(-1)?.id).toBe(
    'command:shelf.toggle',
  );
  expect(
    commandItems('shelves', preferences, {}).some(
      (item) => item.id === 'shelf' || item.id === 'command:shelf.toggle',
    ),
  ).toBe(false);
});
