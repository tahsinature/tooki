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
export function loadPreferences() {
  try {
    const value = JSON.parse(localStorage.getItem(key) ?? '{}');
    preferences.notesFont = isNoteFont(value.notesFont)
      ? value.notesFont
      : 'system';
    for (const name of ['notesToolbar', 'notesKeepOnTop'] as const)
      if (typeof value[name] === 'boolean') preferences[name] = value[name];
    if (typeof value.compactLauncher === 'boolean')
      preferences.compactLauncher = value.compactLauncher;
    if (typeof value.groupByDate === 'boolean')
      preferences.groupByDate = value.groupByDate;
    if (typeof value.rememberPosition === 'boolean')
      preferences.rememberPosition = value.rememberPosition;
  } catch {
    preferences.error = 'Saved preferences could not be loaded.';
  }
}
type PreferenceName = Exclude<keyof typeof preferences, 'error'>;
export function setPreference<K extends PreferenceName>(
  name: K,
  value: (typeof preferences)[K],
) {
  preferences[name] = value;
  try {
    localStorage.setItem(key, JSON.stringify(preferences));
    preferences.error = '';
  } catch {
    preferences.error = 'This preference could not be saved on this device.';
  }
}

export function initializePreferences() {
  loadPreferences();
  const changed = (event: StorageEvent) => {
    if (event.key === key || event.key === null) loadPreferences();
  };
  window.addEventListener('storage', changed);
  window.addEventListener('focus', loadPreferences);
  return () => {
    window.removeEventListener('storage', changed);
    window.removeEventListener('focus', loadPreferences);
  };
}
