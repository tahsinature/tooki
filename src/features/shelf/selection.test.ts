import { expect, test } from 'bun:test';
import { emptySelection, selectItem } from './selection';
test('Shift arrows add visited items; modifier clicks toggle individual items like Swift', () => {
  const order = ['a', 'b', 'c', 'd'];
  const start = selectItem(order, emptySelection(), 'b');
  const next = selectItem(order, start, 'c', true);
  const reversed = selectItem(order, next, 'b', true);
  expect(reversed.ids).toEqual(['b', 'c']);
  expect(selectItem(order, reversed, 'c', false, true).ids).toEqual(['b']);
  expect(selectItem(order, reversed, 'a').ids).toEqual(['a']);
});
