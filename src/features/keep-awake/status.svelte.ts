import { onMount } from 'svelte';
import { invoke, isTauri } from '@tauri-apps/api/core';

export type KeepAwakeStatus = {
  supported: boolean;
  showMenuBarIcon: boolean;
  active: boolean;
  mode: 'system' | 'display';
  remainingSeconds: number | null;
  durationMinutes: number | null;
};

export function statusText(status: KeepAwakeStatus): string {
  if (!status.supported) return 'Keep Awake is available on macOS only.';
  if (!status.active) return 'Keep Awake is off';
  const mode =
    status.mode === 'display' ? 'Display and system awake' : 'System awake';
  if (status.remainingSeconds === null) return `${mode} · Until turned off`;
  const seconds = Math.max(0, status.remainingSeconds);
  const minutes = Math.floor(seconds / 60);
  return `${mode} · ${minutes}:${String(seconds % 60).padStart(2, '0')} remaining`;
}

// Mounted surfaces read the native owner; hiding a window never stops a session.
export function observeKeepAwake() {
  const state = $state({
    value: null as KeepAwakeStatus | null,
    error: '',
  });
  let disposed = false;
  let request = 0;
  async function refresh() {
    if (!isTauri()) return;
    const current = ++request;
    try {
      const value = await invoke<KeepAwakeStatus>('keep_awake_status');
      if (!disposed && current === request) {
        state.value = value;
        state.error = '';
      }
    } catch (error) {
      if (!disposed && current === request) state.error = String(error);
    }
  }
  onMount(() => {
    void refresh();
    const timer = setInterval(() => void refresh(), 1000);
    return () => {
      disposed = true;
      clearInterval(timer);
    };
  });
  return { state, refresh };
}
