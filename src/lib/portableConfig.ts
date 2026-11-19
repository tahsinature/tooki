import { isTauri } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
// Readers use the loaded snapshot. Refresh after in-app saves or explicit reload.
export function observePortableConfig(
  load: () => Promise<void>,
  error: (message: string) => void,
) {
  let disposed = false;
  let stops: (() => void)[] = [];
  const refresh = () => {
    void load().catch((reason) => error(String(reason)));
  };
  if (isTauri())
    void (async () => {
      const listeners = await Promise.all([
        listen('portable-config-changed', refresh),
        listen<string>('portable-config-error', ({ payload }) => {
          error(payload);
        }),
      ]);
      if (disposed) {
        listeners.forEach((stop) => stop());
        return;
      }
      stops = listeners;
      refresh();
    })().catch((reason) => error(String(reason)));
  else refresh();
  window.addEventListener('focus', refresh);
  return () => {
    disposed = true;
    stops.forEach((stop) => stop());
    window.removeEventListener('focus', refresh);
  };
}
