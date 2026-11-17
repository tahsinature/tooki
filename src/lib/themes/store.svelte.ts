import { parseTheme, presets, themeVariables, type Theme } from './theme';
import { invoke, isTauri } from '@tauri-apps/api/core';
const key = 'tooki-preview-themes-v1';
export const themeState = $state({
  selected: 'graphite',
  custom: [] as Theme[],
  storageError: '',
});
export function allThemes() {
  return [...presets, ...themeState.custom];
}
export function activeTheme() {
  return (
    allThemes().find((theme) => theme.id === themeState.selected) ?? presets[0]
  );
}
export function saveEditedTheme(source: Theme) {
  const theme = parseTheme(JSON.stringify(source));
  if (presets.some((preset) => preset.id === theme.id))
    throw new Error('Built-in themes must be saved as a copy.');
  const exists = themeState.custom.some((item) => item.id === theme.id);
  if (!exists && themeState.custom.length >= 50)
    throw new Error('Remove a custom theme before adding another (limit 50).');
  const custom = exists
    ? themeState.custom.map((item) => (item.id === theme.id ? theme : item))
    : [...themeState.custom, theme];
  localStorage.setItem(key, JSON.stringify({ selected: theme.id, custom }));
  themeState.custom = custom;
  themeState.selected = theme.id;
  themeState.storageError = '';
  applyTheme();
}
let previousVariables: string[] = [];
let nativeRadius: number | undefined;
export function applyTheme() {
  const theme = activeTheme();
  const variables = themeVariables(theme);
  for (const name of previousVariables)
    document.documentElement.style.removeProperty(name);
  for (const [name, value] of Object.entries(variables))
    document.documentElement.style.setProperty(name, value);
  previousVariables = Object.keys(variables);
  document.documentElement.style.colorScheme = theme.appearance;
  document.documentElement.dataset.theme = theme.id;
  const surface = new URLSearchParams(location.search).get('window');
  const radius = theme.tokens.cornerRadius ?? theme.tokens.shellRadius;
  if (
    isTauri() &&
    (surface === 'notes' || surface === 'shelf') &&
    radius !== nativeRadius
  ) {
    nativeRadius = radius;
    void invoke('set_window_corner_radius', { radius }).catch((error) => {
      nativeRadius = undefined;
      console.error('Could not update window corners:', error);
    });
  }
}
function save() {
  applyTheme();
  try {
    localStorage.setItem(
      key,
      JSON.stringify({
        selected: themeState.selected,
        custom: themeState.custom,
      }),
    );
    themeState.storageError = '';
  } catch {
    themeState.storageError =
      'Changes apply now, but could not be saved on this device.';
  }
}
export function selectTheme(id: string) {
  themeState.selected = id;
  save();
}
export function importTheme(source: string) {
  const theme = parseTheme(source);
  if (presets.some((preset) => preset.id === theme.id))
    throw new Error('Choose a new id to customize a built-in theme.');
  if (themeState.custom.some((existing) => existing.id === theme.id))
    throw new Error('A theme with this id already exists. Choose a new id.');
  if (themeState.custom.length >= 50)
    throw new Error(
      'Remove an imported theme before adding another (limit 50).',
    );
  themeState.custom = [...themeState.custom, theme];
  selectTheme(theme.id);
}
export function removeTheme(id: string) {
  themeState.custom = themeState.custom.filter((theme) => theme.id !== id);
  if (themeState.selected === id) themeState.selected = 'graphite';
  save();
}
function loadThemes() {
  try {
    const saved = JSON.parse(localStorage.getItem(key) ?? 'null');
    if (saved) {
      const custom = Array.isArray(saved.custom)
        ? saved.custom
            .slice(0, 50)
            .map((theme: unknown) => parseTheme(JSON.stringify(theme)))
        : [];
      themeState.custom = custom.filter(
        (theme: Theme, index: number) =>
          !presets.some((preset) => preset.id === theme.id) &&
          custom.findIndex((other: Theme) => other.id === theme.id) === index,
      );
      if (typeof saved.selected === 'string')
        themeState.selected = saved.selected;
    }
  } catch {
    themeState.storageError =
      'Saved themes could not be loaded. Using Graphite.';
  }
  applyTheme();
}
export function initializeThemes() {
  loadThemes();
  const changed = (event: StorageEvent) => {
    if (event.key === key || event.key === null) loadThemes();
  };
  window.addEventListener('storage', changed);
  window.addEventListener('focus', loadThemes);
  return () => {
    window.removeEventListener('storage', changed);
    window.removeEventListener('focus', loadThemes);
  };
}
