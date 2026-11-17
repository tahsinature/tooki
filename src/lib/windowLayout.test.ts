import { expect, test } from 'bun:test';
import { windowDimensions } from './windowLayout';
test('compact height follows themed search header while tool panels stay expanded', () => {
  expect(windowDimensions('compact', 54)).toEqual({ width: 760, height: 94 });
  expect(windowDimensions('compact', 80).height).toBe(120);
  expect(windowDimensions('expanded', 54).height).toBe(520);
});
