import { test, expect } from 'bun:test';
import { comboFromEvent, labels } from './api';
function event(overrides: Partial<KeyboardEvent> = {}): KeyboardEvent {
  return {
    key: 'a',
    code: 'KeyA',
    ctrlKey: false,
    altKey: false,
    shiftKey: false,
    metaKey: false,
    repeat: false,
    isComposing: false,
    ...overrides,
  } as KeyboardEvent;
}
test('Detective ignores typing, composition, repeats and modifier-only presses', () => {
  for (const input of [
    event(),
    event({ shiftKey: true }),
    event({ ctrlKey: true, repeat: true }),
    event({ ctrlKey: true, isComposing: true }),
    event({ key: 'Control', code: 'ControlLeft', ctrlKey: true }),
  ])
    expect(comboFromEvent(input)).toBeNull();
});
test('Detective accepts function keys and physical modifier combinations', () => {
  expect(comboFromEvent(event({ key: 'F5', code: 'F5' }))).toEqual({
    key: 'F5',
    modifiers: 0,
  });
  expect(
    comboFromEvent(event({ key: 'å', code: 'KeyA', altKey: true })),
  ).toEqual({ key: 'KeyA', modifiers: 2 });
});
test('Shortcut results use platform-appropriate keycaps', () => {
  expect(labels({ key: 'space', modifiers: 12 }, 'macOS')).toEqual([
    '⇧',
    '⌘',
    'Space',
  ]);
  expect(labels({ key: 'space', modifiers: 12 }, 'Windows')).toEqual([
    'Shift',
    'Win',
    'Space',
  ]);
  expect(labels({ key: 'space', modifiers: 12 }, 'Linux · Wayland')).toEqual([
    'Shift',
    'Super',
    'Space',
  ]);
});

import { mergeSnapshot, type Snapshot } from './api';
const snapshot = (
  revision: number,
  ids: number[],
  replaceChecks = false,
): Snapshot => ({
  revision,
  replaceChecks,
  listening: true,
  message: null,
  capabilities: {
    platform: 'macOS',
    canObserve: true,
    canBlock: true,
    explanation: '',
  },
  checks: ids.map((id) => ({
    id,
    timestamp: id,
    combo: { key: 'f', modifiers: 8 },
    outcome: 'observed',
    detail: '',
    app: null,
    matches: [],
  })),
});
test('Log updates append without duplicate replay and full snapshots replace history', () => {
  const first = snapshot(5, [1, 2], true);
  const appended = mergeSnapshot(first, snapshot(6, [3]));
  expect(appended.checks.map((check) => check.id)).toEqual([1, 2, 3]);
  expect(mergeSnapshot(appended, snapshot(6, [3])).checks).toHaveLength(3);
  expect(mergeSnapshot(appended, snapshot(4, [9]))).toBe(appended);
  expect(mergeSnapshot(appended, snapshot(7, [], true)).checks).toHaveLength(0);
});
