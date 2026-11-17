import { test, expect } from 'bun:test';
import { createDragController, type DragCommand } from './dragController';
test('ordinary clicks do not move or save the launcher', async () => {
  const calls: [DragCommand, unknown][] = [];
  const drag = createDragController(
    async (c, a) => {
      calls.push([c, a]);
    },
    () => {},
  );
  drag.start(10, 10);
  drag.move(12, 11);
  await drag.end();
  expect(calls).toEqual([
    ['launcher_drag_start', { x: 10, y: 10 }],
    ['launcher_drag_end', { save: false }],
  ]);
});
test('motion waits for start and drop waits for the final move', async () => {
  const calls: string[] = [];
  let begin!: () => void;
  const pending = new Promise<void>((resolve) => (begin = resolve));
  const drag = createDragController(
    async (c) => {
      calls.push(c);
      if (c === 'launcher_drag_start') await pending;
    },
    () => {},
  );
  drag.start(0, 0);
  drag.move(10, 0);
  drag.move(20, 0);
  const end = drag.end();
  expect(calls).toEqual(['launcher_drag_start']);
  begin();
  await end;
  expect(calls).toEqual([
    'launcher_drag_start',
    'launcher_drag_move',
    'launcher_drag_end',
  ]);
});
test('moves coalesce during a slow native request and cancellation never saves', async () => {
  const calls: [string, unknown][] = [];
  let release!: () => void;
  const pending = new Promise<void>((resolve) => (release = resolve));
  const drag = createDragController(
    async (c, a) => {
      calls.push([c, a]);
      if (c === 'launcher_drag_move' && calls.length === 2) await pending;
    },
    () => {},
  );
  drag.start(0, 0);
  drag.move(10, 10);
  await Promise.resolve();
  await Promise.resolve();
  drag.move(20, 20);
  drag.move(30, 30);
  const end = drag.end(true);
  release();
  await end;
  expect(calls.map((c) => c[0])).toEqual([
    'launcher_drag_start',
    'launcher_drag_move',
    'launcher_drag_move',
    'launcher_drag_end',
  ]);
  expect(calls.at(-1)?.[1]).toEqual({ save: false });
});
test('failed moves report an error and still end the native session', async () => {
  const calls: string[] = [];
  const errors: unknown[] = [];
  const drag = createDragController(
    async (c) => {
      calls.push(c);
      if (c === 'launcher_drag_move') throw Error('disconnected');
    },
    (e) => errors.push(e),
  );
  drag.start(0, 0);
  drag.move(5, 0);
  await drag.end();
  expect(errors).toHaveLength(1);
  expect(calls.at(-1)).toBe('launcher_drag_end');
});
