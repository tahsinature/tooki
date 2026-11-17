import { invoke } from '@tauri-apps/api/core';
export type Combo = { key: string; modifiers: number };
export type Check = {
  id: number;
  timestamp: number;
  combo: Combo;
  outcome: string;
  detail: string;
  app: string | null;
  matches: { owner: string; detail: string }[];
};
export type Snapshot = {
  revision: number;
  replaceChecks: boolean;
  listening: boolean;
  capabilities: {
    platform: string;
    canObserve: boolean;
    canBlock: boolean;
    explanation: string;
  };
  checks: Check[];
  message: string | null;
};
export function request(
  operation: string,
  mode?: 'observe' | 'block',
  combo?: Combo,
) {
  return invoke<Snapshot>('detective_request', { operation, mode, combo });
}
export function comboFromEvent(event: KeyboardEvent): Combo | null {
  const key =
    event.code || (event.key === ' ' ? 'space' : event.key.toLowerCase());
  if (
    event.isComposing ||
    event.repeat ||
    ['meta', 'control', 'shift', 'alt', 'dead', 'unidentified'].includes(
      event.key.toLowerCase(),
    )
  )
    return null;
  const modifiers =
    (event.ctrlKey ? 1 : 0) |
    (event.altKey ? 2 : 0) |
    (event.shiftKey ? 4 : 0) |
    (event.metaKey ? 8 : 0);
  if (!(modifiers & 11) && !/^f([1-9]|1\d|2[0-4])$/.test(key.toLowerCase()))
    return null;
  return { key, modifiers };
}
export function labels(combo: Combo, platform: string): string[] {
  const mac = platform === 'macOS';
  return [
    ...(combo.modifiers & 1 ? [mac ? '⌃' : 'Ctrl'] : []),
    ...(combo.modifiers & 2 ? [mac ? '⌥' : 'Alt'] : []),
    ...(combo.modifiers & 4 ? [mac ? '⇧' : 'Shift'] : []),
    ...(combo.modifiers & 8
      ? [mac ? '⌘' : platform === 'Windows' ? 'Win' : 'Super']
      : []),
    (
      {
        space: 'Space',
        escape: 'Esc',
        enter: 'Enter',
        backspace: '⌫',
        left: '←',
        right: '→',
        up: '↑',
        down: '↓',
      } as Record<string, string>
    )[combo.key] ??
      (combo.key.length === 1 ? combo.key.toUpperCase() : combo.key),
  ];
}
export function outcomeTitle(outcome: string): string {
  return (
    (
      {
        lookup: 'Known assignments',
        delivered: 'Reached the app event stream',
        intercepted: 'Possible interception',
        observed: 'Shortcut observed',
      } as Record<string, string>
    )[outcome] ?? 'Shortcut checked'
  );
}

export function mergeSnapshot(
  current: Snapshot | null,
  incoming: Snapshot,
): Snapshot {
  if (current && incoming.revision < current.revision) return current;
  if (incoming.replaceChecks || !current) return incoming;
  const lastId = current.checks.at(-1)?.id ?? 0;
  return {
    ...incoming,
    checks: [
      ...current.checks,
      ...incoming.checks.filter((check) => check.id > lastId),
    ],
  };
}
