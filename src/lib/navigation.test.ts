import { test } from 'bun:test';
import { strict as assert } from 'node:assert';
import { nextIndex } from './navigation.ts';
test('page movement and command jumps have distinct behavior', () => {
  assert.equal(nextIndex('PageDown', 2, 30, 6), 8);
  assert.equal(nextIndex('ArrowDown', 2, 30, 6, true), 29);
  assert.equal(nextIndex('ArrowUp', 29, 30, 6, true), 0);
});
test('empty and boundary navigation stays in range', () => {
  assert.equal(nextIndex('ArrowUp', 0, 30, 6), 0);
  assert.equal(nextIndex('PageDown', 28, 30, 6), 29);
  assert.equal(nextIndex('End', 0, 0, 6), 0);
});
