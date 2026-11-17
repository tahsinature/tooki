import { invoke, isTauri } from '@tauri-apps/api/core';
import { observePortableConfig } from './portableConfig';
import { isNoteFont, type NoteFont } from '../features/notes/fonts';
const key = 'tooki-preview-preferences-v1';
export const preferences = $state({
  notesFont: 'system' as NoteFont,
  notesToolbar: true,
  notesKeepOnTop: false,
  compactLauncher: true,
  groupByDate: true,
  rememberPosition: true,
  error: '',
});
export async function loadPreferences() {
  try {
    const legacy = JSON.parse(localStorage.getItem(key) ?? '{}');
    const value = isTauri()
      ? await invoke<Record<string, unknown>>('portable_preferences', {
          legacy,
        })
      : legacy;
    preferences.notesFont = isNoteFont(value.notesFont)
      ? value.notesFont
      : 'system';
    const defaults = { notesToolbar: true, notesKeepOnTop: false, compactLauncher: true, groupByDate: true, rememberPosition: true };
    for (const name of Object.keys(defaults) as (keyof typeof defaults)[])
      preferences[name] = typeof value[name] === 'boolean' ? value[name] : defaults[name];
    preferences.error = '';
  } catch (error) {
    preferences.error = String(error);
  }
}
type PreferenceName = Exclude<keyof typeof preferences, 'error'>;
export async function setPreference<K extends PreferenceName>(
  name: K,
  value: (typeof preferences)[K],
) {
  preferences[name] = value;
  try {
    if (isTauri()) await invoke('set_portable_preference', { name, value });
    else localStorage.setItem(key, JSON.stringify(preferences));
    preferences.error = '';
  } catch {
    preferences.error = 'This preference could not be saved on this device.';
  }
}

export function initializePreferences() {
  return observePortableConfig(loadPreferences, (error) => {
    preferences.error = error;
  });
}
