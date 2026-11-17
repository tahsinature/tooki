import { invoke, isTauri } from '@tauri-apps/api/core';
export type WindowMode = 'compact' | 'expanded';
export function windowDimensions(mode: WindowMode, headerHeight = 54) {
  return { width: 760, height: mode === 'expanded' ? 520 : headerHeight + 40 };
}
// Serialize native requests so rapid typing cannot leave a stale compact size last.
let pending = Promise.resolve();
let revision = 0;
export function resizeWindow(mode: WindowMode, headerHeight: number) {
  if (!isTauri()) return Promise.resolve();
  const current = ++revision;
  pending = pending.catch(() => {}).then(async () => {
    if (current !== revision) return;
    const size = windowDimensions(mode, headerHeight);
    await invoke('resize_launcher', size);
  });
  return pending;
}
