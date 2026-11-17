import { test, expect } from 'bun:test';
import {
  filterEntries,
  logJson,
  logText,
  nextRow,
  type ActivityLogEntry,
} from './model';
const entries: ActivityLogEntry[] = Array.from(
  { length: 5000 },
  (_, index) => ({
    id: String(index),
    timestamp: 1_700_000_000_000 + index,
    category: index % 2 ? 'observed' : 'lookup',
    cells: { shortcut: { text: '⌘ Space' }, app: { text: `App ${index}` } },
    details: [{ label: 'Result', value: `Detail ${index}` }],
  }),
);
test('Filtering searches details, combines terms and keeps every matching result', () => {
  expect(filterEntries(entries, '', 'all')).toHaveLength(5000);
  expect(
    filterEntries(entries, 'Detail 4999', 'observed').map((entry) => entry.id),
  ).toEqual(['4999']);
  expect(filterEntries(entries, 'Detail 4999', 'lookup')).toHaveLength(0);
});
test('Exports include offscreen records and multiline details', () => {
  const json = JSON.parse(
    logJson(entries, [{ id: 'app', title: 'Application' }]),
  );
  expect(json.entries).toHaveLength(5000);
  expect(json.entries[4999].id).toBe('4999');
  const text = logText(entries.slice(-1), [
    { id: 'app', title: 'Application' },
  ]);
  expect(text).toContain('Application: App 4999');
  expect(text).toContain('Result: Detail 4999');
});
test('Log keyboard navigation distinguishes pages and boundary jumps', () => {
  expect(nextRow('PageDown', 20, 5000, 7, false)).toBe(27);
  expect(nextRow('ArrowDown', 20, 5000, 7, true)).toBe(4999);
  expect(nextRow('Home', 4999, 5000, 7, false)).toBe(0);
  expect(nextRow('ArrowUp', 0, 5000, 7, false)).toBe(0);
  expect(nextRow('ArrowDown', 0, 0, 7, false)).toBeNull();
});
