import { invoke, isTauri } from '@tauri-apps/api/core';
export type WindowMode = 'compact' | 'expanded';
// Serialize native requests so rapid typing cannot leave a stale compact size last.
let pending = Promise.resolve();
let revision = 0;
export function resizeWindow(mode: WindowMode, headerHeight: number) {
  if (!isTauri()) return Promise.resolve();
  const current = ++revision;
  pending = pending.catch(() => {}).then(async () => {
    if (current !== revision) return;
    await invoke('resize_launcher', { mode, headerHeight });
  });
  return pending;
}
