import { expect, test } from 'bun:test';
import { initializeRootSearchShortcut } from './rootSearchShortcut';

function key(properties: Partial<KeyboardEvent> = {}) {
  return Object.assign(new Event('keydown', { cancelable: true }), {
    key: 'Escape',
    metaKey: false,
    ctrlKey: false,
    isComposing: false,
    repeat: false,
    ...properties,
  });
}

test('Command/Ctrl Escape returns once and cannot also dismiss the launcher', () => {
  const target = new EventTarget();
  let opened = 0;
  let downstream = 0;
  const stop = initializeRootSearchShortcut(() => opened++, target);
  target.addEventListener('keydown', () => downstream++);
  for (const modifier of [{ metaKey: true }, { ctrlKey: true }]) {
    const event = key(modifier);
    target.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  }
  target.dispatchEvent(key({ metaKey: true, repeat: true }));
  expect(opened).toBe(2);
  expect(downstream).toBe(0);
  stop();
  target.dispatchEvent(key({ metaKey: true }));
  expect(opened).toBe(2);
  expect(downstream).toBe(1);
});

test('plain Escape, other shortcuts, and composition keep their own handlers', () => {
  const target = new EventTarget();
  let opened = 0;
  let downstream = 0;
  const stop = initializeRootSearchShortcut(() => opened++, target);
  target.addEventListener('keydown', () => downstream++);
  for (const event of [
    key(),
    key({ key: 'k', metaKey: true }),
    key({ metaKey: true, isComposing: true }),
  ]) {
    target.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(false);
  }
  expect(opened).toBe(0);
  expect(downstream).toBe(3);
  stop();
});
