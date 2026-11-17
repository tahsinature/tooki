import { test, expect } from 'bun:test';
import { sections, gridRows, move, type Emoji, type Library } from './model';
const rocket: Emoji = {
  character: '🚀',
  name: 'rocket',
  group: 'Travel',
  keywords: ['ship', 'launch'],
  shortcodes: ['rocket'],
  shortcode: 'rocket',
};
const thumb: Emoji = {
  character: '👍',
  name: 'thumbs up',
  group: 'People',
  keywords: ['like', 'yes'],
  shortcodes: ['+1', 'thumbsup'],
  shortcode: '+1',
};
const library: Library = {
  items: [rocket, thumb],
  groups: ['People', 'Travel'],
  recent: ['invalid', '🚀'],
  canPaste: true,
};
test('emoji search ranks names and accepts keywords, shortcodes, and characters', () => {
  for (const query of ['rocket', ':rocket:', 'launch', '🚀'])
    expect(sections(library, query, 'all')[0].items[0]).toBe(rocket);
  expect(sections(library, 'like', 'all')[0].items[0]).toBe(thumb);
  expect(sections(library, 'zzzqqq', 'all')).toEqual([]);
  expect(sections(library, 'rocket', 'People')).toEqual([]);
});
test('recent and category copies have distinct identities; stale history is ignored', () => {
  const rows = gridRows(sections(library, '', 'all'));
  const cells = rows.flatMap((row) => row.cells);
  expect(cells).toHaveLength(3);
  expect(new Set(cells.map((cell) => cell.id)).size).toBe(3);
  expect(sections(library, '', 'recent')[0].items).toEqual([rocket]);
});
test('grid movement crosses partial category rows and stays bounded', () => {
  const rows = gridRows([
    { title: 'A', items: Array(13).fill(rocket) },
    { title: 'B', items: Array(15).fill(thumb) },
  ]);
  expect(move(rows, 9, 'ArrowDown', 5, false)).toBe(12);
  expect(move(rows, 12, 'ArrowDown', 5, false)).toBe(15);
  expect(move(rows, 0, 'ArrowLeft', 5, false)).toBe(0);
  expect(move(rows, 27, 'ArrowRight', 5, false)).toBe(27);
  expect(move(rows, 3, 'End', 5, false)).toBe(27);
  expect(move(rows, 27, 'ArrowUp', 5, true)).toBe(0);
});
