import { commandSupport } from './availability.svelte';
import { unavailableReason } from './availability';
import { invoke, isTauri } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import {
  appPreferences,
  updateAppPreference,
} from '../launcher/app-preferences.svelte';
export const launcherDefault = 'CommandOrControl+Space';
export const launcherAssignment = $state({
  shortcut: launcherDefault,
  error: '',
});
export type Assignment = {
  id: string;
  title: string;
  group: string;
  shortcut: string;
  alias: string;
  error?: string;
  unavailable?: string;
  customized: boolean;
  launcher?: boolean;
};
export async function saveAssignment(
  item: Assignment,
  update: { alias?: string; shortcut?: string },
) {
  if (item.launcher) {
    launcherAssignment.shortcut = await invoke<string>(
      'set_launcher_shortcut',
      { shortcut: update.shortcut || launcherDefault },
    );
    launcherAssignment.error = '';
  } else await updateAppPreference(item.id, update);
}
export function assignment(
  id: string,
  title: string,
  group: string,
): Assignment {
  const preference = appPreferences.values[id];
  return {
    id,
    title,
    group,
    shortcut: preference?.shortcut ?? '',
    alias: preference?.alias ?? '',
    error: preference?.shortcut_error,
    unavailable: unavailableReason(id, commandSupport.values),
    customized: !!(preference?.shortcut || preference?.alias),
  };
}
export function launcherRow(): Assignment {
  const equivalentDefault = [
    'CommandOrControl+Space',
    /Mac/.test(navigator.platform) ? 'Super+Space' : 'Control+Space',
  ].includes(launcherAssignment.shortcut);
  return {
    id: 'launcher',
    title: 'Open launcher',
    group: 'General',
    shortcut: launcherAssignment.shortcut,
    alias: '',
    error: launcherAssignment.error,
    customized: !equivalentDefault,
    launcher: true,
  };
}
export function observeLauncherAssignment() {
  let disposed = false;
  let stop: (() => void) | undefined;
  if (isTauri())
    void (async () => {
      const unsubscribe = await listen<string>(
        'launcher-shortcut-changed',
        ({ payload }) => {
          launcherAssignment.shortcut = payload;
          launcherAssignment.error = '';
        },
      );
      if (disposed) {
        unsubscribe();
        return;
      }
      stop = unsubscribe;
      try {
        launcherAssignment.shortcut = await invoke('get_launcher_shortcut');
      } catch (error) {
        launcherAssignment.error = String(error);
      }
    })().catch((error) => (launcherAssignment.error = String(error)));
  return () => {
    disposed = true;
    stop?.();
  };
}
