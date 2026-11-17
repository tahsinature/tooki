export type DragCommand =
  'launcher_drag_start' | 'launcher_drag_move' | 'launcher_drag_end';
type Send = (
  command: DragCommand,
  args?: Record<string, number | boolean>,
) => Promise<unknown>;
/** One in-flight move, latest motion coalesced. End waits for the last move. */
export function createDragController(
  send: Send,
  onerror: (error: unknown) => void,
) {
  let origin: { x: number; y: number } | undefined;
  let delta = { dx: 0, dy: 0 };
  let moved = false;
  let dirty = false;
  let running = false;
  let closing = false;
  let ready: Promise<unknown> = Promise.resolve();
  let completion: Promise<void> = Promise.resolve();
  function fail(error: unknown) {
    onerror(error);
    origin = undefined;
    dirty = false;
  }
  async function drain() {
    if (running) return;
    running = true;
    try {
      await ready;
      while (dirty) {
        dirty = false;
        await send('launcher_drag_move', { ...delta });
      }
    } catch (error) {
      fail(error);
    } finally {
      running = false;
    }
  }
  return {
    start(x: number, y: number) {
      if (origin || closing) return;
      origin = { x, y };
      moved = false;
      dirty = false;
      ready = send('launcher_drag_start', { x, y }).catch(fail);
    },
    move(x: number, y: number) {
      if (!origin || closing) return;
      if (!moved && Math.hypot(x - origin.x, y - origin.y) < 4) return;
      delta = { dx: x - origin.x, dy: y - origin.y };
      moved = true;
      dirty = true;
      if (!running) completion = drain();
    },
    async end(cancelled = false) {
      if (closing) return;
      closing = true;
      const save = moved && !cancelled;
      origin = undefined;
      try {
        await ready;
        await completion;
        await send('launcher_drag_end', { save });
      } catch (error) {
        onerror(error);
      } finally {
        closing = false;
        moved = false;
      }
    },
  };
}
