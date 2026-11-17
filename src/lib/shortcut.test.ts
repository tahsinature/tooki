import { expect, test } from 'bun:test';
import { shortcutFromEvent, shortcutLabels } from './shortcut';
const key = { code: 'KeyK', metaKey: false, ctrlKey: false, altKey: false, shiftKey: false, isComposing: false };

test('recording requires a command, control, or alt modifier', () => {
  expect(shortcutFromEvent(key)).toBeNull();
  expect(shortcutFromEvent({ ...key, shiftKey: true })).toBeNull();
  expect(shortcutFromEvent({ ...key, metaKey: true })).toBe('Super+KeyK');
  expect(shortcutFromEvent({ ...key, ctrlKey: true, altKey: true, shiftKey: true })).toBe('Control+Alt+Shift+KeyK');
});
test('recording uses physical keys and ignores composition and modifier-only events', () => {
  expect(shortcutFromEvent({ ...key, code: 'Space', altKey: true })).toBe('Alt+Space');
  expect(shortcutFromEvent({ ...key, code: 'ShiftLeft', metaKey: true })).toBeNull();
  expect(shortcutFromEvent({ ...key, metaKey: true, isComposing: true })).toBeNull();
  expect(shortcutLabels('Control+Shift+Digit2')).toEqual(['Ctrl', '⇧', '2']);
});
