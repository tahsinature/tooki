import { expect, test } from 'bun:test';
import { matchScore, searchItems } from './search';
import { commands, type Item } from '../../lib/data';
test('Swift matching tiers include initials, accents and subsequences', () => {
  expect(matchScore('cafe', 'Café')).toBe(100);
  expect(matchScore('gc', 'Google Chrome')).toBe(70);
  expect(matchScore('gchr', 'Google Chrome')).toBe(30);
  expect(matchScore('safari', 'Calendar')).toBeNull();
});
test('exact app matches precede weaker matches and filters isolate commands', () => {
  const apps: Item[] = ['Notes Helper', 'Notes'].map((title) => ({
    ...commands[0],
    id: `app:${title}`,
    title,
    kind: 'application',
  }));
  const results = searchItems([...apps, ...commands], 'notes', 'all');
  expect(results.map((item) => item.title)).toEqual([
    'Notes',
    'Notes',
    'Notes Helper',
  ]);
  expect(searchItems([...apps, ...commands], '', 'command')).toHaveLength(
    commands.length,
  );
  expect(new Set(commands.map((item) => item.id)).size).toBe(commands.length);
});

test('aliases outrank title matches and favorites lead empty searches', () => {
  const app: Item = {
    ...commands[0],
    id: 'app:browser',
    title: 'Browser',
    kind: 'application',
    alias: 'notes',
    pinned: true,
  };
  expect(searchItems([...commands, app], 'NOTES', 'all')[0].id).toBe(app.id);
  expect(searchItems([...commands, app], '', 'all')[0].id).toBe(app.id);
  expect(
    searchItems([...commands, app], 'notes', 'command').some(
      (item) => item.id === app.id,
    ),
  ).toBe(false);
});

test('favorites filter includes only favorite apps and respects query and aliases', () => {
  const favorite: Item = {
    ...commands[0],
    id: 'app:browser',
    title: 'Browser',
    kind: 'application',
    alias: 'web',
    pinned: true,
  };
  const ordinary: Item = { ...favorite, id: 'app:other', pinned: false };
  const items = [
    ...commands,
    favorite,
    ordinary,
    { ...commands[1], pinned: true },
  ];
  expect(searchItems(items, '', 'favorites').map((item) => item.id)).toEqual([
    favorite.id,
  ]);
  expect(searchItems(items, 'web', 'favorites').map((item) => item.id)).toEqual(
    [favorite.id],
  );
  expect(searchItems(items, 'unmatched', 'favorites')).toEqual([]);
  expect(searchItems([ordinary], '', 'favorites')).toEqual([]);
});
