import { listen } from '@tauri-apps/api/event';
import { invoke, isTauri } from '@tauri-apps/api/core';
export type AppPreference = {
  favorite: boolean;
  alias: string;
  shortcut: string;
  shortcut_error?: string;
};
export const appPreferences = $state({
  values: {} as Record<string, AppPreference>,
});
export async function loadAppPreferences() {
  if (isTauri())
    appPreferences.values = await invoke('application_preferences');
}
export async function updateAppPreference(
  id: string,
  update: Partial<AppPreference>,
) {
  appPreferences.values = await invoke('update_application_preference', {
    id,
    ...update,
  });
}

export function observeAppPreferences(
  onerror: (message: string) => void = console.error,
) {
  let disposed = false;
  let stop: (() => void) | undefined;
  if (isTauri())
    void (async () => {
      const unlisten = await listen<Record<string, AppPreference>>(
        'application-preferences-changed',
        (event) => {
          appPreferences.values = event.payload;
        },
      );
      if (disposed) {
        unlisten();
        return;
      }
      stop = unlisten;
      await loadAppPreferences();
    })().catch((reason) => onerror(String(reason)));
  return () => {
    disposed = true;
    stop?.();
  };
}
