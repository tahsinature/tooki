import { parseTheme, presets, themeVariables, type Theme } from './theme';
import { invoke, isTauri } from '@tauri-apps/api/core';
import { observePortableConfig } from '../portableConfig';
const key = 'tooki-preview-themes-v1';
const rawThemes = new Map<string, unknown>();
export function themeSource(id: string) {
  return (
    rawThemes.get(id) ?? themeState.custom.find((t) => t.id === id) ?? null
  );
}
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
export async function saveEditedTheme(source: Theme, expected?: unknown) {
  const theme = parseTheme(JSON.stringify(source));
  if (presets.some((preset) => preset.id === theme.id))
    throw new Error('Built-in themes must be saved as a copy.');
  const exists = themeState.custom.some((item) => item.id === theme.id);
  if (!exists && themeState.custom.length >= 50)
    throw new Error('Remove a custom theme before adding another (limit 50).');
  const custom = exists
    ? themeState.custom.map((item) => (item.id === theme.id ? theme : item))
    : [...themeState.custom, theme];
  if (isTauri()) {
    await invoke('write_portable_theme', {
      id: theme.id,
      theme,
      expected: expected ?? null,
    });
    await invoke('select_portable_theme', { id: theme.id });
  } else
    localStorage.setItem(key, JSON.stringify({ selected: theme.id, custom }));
  rawThemes.set(theme.id, theme);
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
async function save() {
  applyTheme();
  try {
    if (isTauri())
      await invoke('select_portable_theme', { id: themeState.selected });
    else
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
export async function selectTheme(id: string) {
  themeState.selected = id;
  await save();
}
export async function importTheme(source: string) {
  const theme = parseTheme(source);
  if (presets.some((preset) => preset.id === theme.id))
    throw new Error('Choose a new id to customize a built-in theme.');
  if (themeState.custom.some((existing) => existing.id === theme.id))
    throw new Error('A theme with this id already exists. Choose a new id.');
  if (themeState.custom.length >= 50)
    throw new Error(
      'Remove an imported theme before adding another (limit 50).',
    );
  await saveEditedTheme(theme);
}
export async function removeTheme(id: string) {
  try {
    if (isTauri())
      await invoke('write_portable_theme', {
        id,
        theme: null,
        expected: themeSource(id),
      });
    themeState.custom = themeState.custom.filter((theme) => theme.id !== id);
    if (themeState.selected === id) themeState.selected = 'graphite';
    await save();
  } catch (error) {
    themeState.storageError = String(error);
  }
}
async function loadThemes() {
  try {
    const legacy = JSON.parse(localStorage.getItem(key) ?? 'null');
    const saved = isTauri()
      ? await invoke<{ selected: string; custom: unknown[] }>(
          'portable_themes',
          { legacy },
        )
      : legacy;
    if (saved) {
      const custom = Array.isArray(saved.custom)
        ? saved.custom
            .slice(0, 50)
            .map((theme: unknown) => parseTheme(JSON.stringify(theme)))
        : [];
      rawThemes.clear();
      for (const theme of saved.custom ?? []) {
        if (theme && typeof theme === 'object' && 'id' in theme)
          rawThemes.set(String(theme.id), theme);
      }
      themeState.custom = custom.filter(
        (theme: Theme, index: number) =>
          !presets.some((preset) => preset.id === theme.id) &&
          custom.findIndex((other: Theme) => other.id === theme.id) === index,
      );
      if (typeof saved.selected === 'string')
        themeState.selected = saved.selected;
    }
    themeState.storageError = '';
  } catch (error) {
    themeState.storageError = String(error);
  }
  applyTheme();
}
export function initializeThemes() {
  return observePortableConfig(loadThemes, (error) => {
    themeState.storageError = error;
  });
}
