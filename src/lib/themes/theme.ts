import graphite from './graphite.json';
import porcelain from './porcelain.json';
import { radiusVariables } from './radii';

// The allowlist is the theme contract. No selectors, scripts or remote resources.
export const colorTokens = [
  'surface',
  'panel',
  'sidebar',
  'ink',
  'muted',
  'line',
  'selected',
  'hover',
  'accent',
  'accentInk',
  'danger',
  'selectionMark',
] as const;
export const dimensions = {
  shellRadius: [0, 24],
  rowRadius: [0, 16],
  rowHeight: [32, 64],
  headerHeight: [44, 80],
  fontSize: [12, 18],
  searchFontSize: [14, 28],
  contentSpacing: [12, 32],
} as const;
export const componentFields = {
  activityLog: ['background', 'hover', 'selected', 'text', 'radius'],
  sectionHeader: ['background', 'text', 'radius'],
  resultRow: ['background', 'hover', 'selected', 'text', 'radius'],
  searchHeader: ['background', 'text', 'radius'],
  popup: ['background', 'text', 'radius'],
  settingsSection: ['background', 'text', 'radius'],
  button: ['background', 'text', 'radius'],
} as const;
export type ColorToken = (typeof colorTokens)[number];
export type DimensionToken = keyof typeof dimensions;
export type ComponentName = keyof typeof componentFields;
export type Theme = {
  version: 1;
  id: string;
  name: string;
  author: string;
  appearance: 'light' | 'dark';
  tokens: Record<ColorToken, string> &
    Record<DimensionToken, number> & { cornerRadius?: number };
  components: Partial<Record<ComponentName, Record<string, string | number>>>;
};
function record(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function color(value: unknown): value is string {
  return typeof value === 'string' && /^#[\da-f]{6}$/i.test(value);
}
function bounded(value: unknown, min: number, max: number): value is number {
  return (
    typeof value === 'number' &&
    Number.isFinite(value) &&
    value >= min &&
    value <= max
  );
}
export function parseTheme(source: string): Theme {
  if (source.length > 32_000)
    throw new Error('Theme must be smaller than 32 KB.');
  const data: unknown = JSON.parse(source);
  if (!record(data) || data.version !== 1)
    throw new Error('Expected a version 1 Tooki theme.');
  if (typeof data.id !== 'string' || !/^[a-z][a-z0-9-]{0,63}$/.test(data.id))
    throw new Error('Use a short lowercase theme id, such as midnight-blue.');
  for (const key of ['name', 'author']) {
    if (
      typeof data[key] !== 'string' ||
      !data[key].trim() ||
      data[key].length > 80
    )
      throw new Error(`Theme ${key} must be 1–80 characters.`);
  }
  if (data.appearance !== 'dark' && data.appearance !== 'light')
    throw new Error('Appearance must be light or dark.');
  if (!record(data.tokens)) throw new Error('Theme tokens are missing.');
  for (const key of Object.keys(data.tokens)) {
    if (
      key !== 'cornerRadius' &&
      !(colorTokens as readonly string[]).includes(key) &&
      !Object.hasOwn(dimensions, key)
    )
      throw new Error(`Unknown token: ${key}`);
  }
  for (const key of colorTokens)
    if (!color(data.tokens[key]))
      throw new Error(`${key} must be a six-digit hex color.`);
  // Existing exported themes keep their original search text size.
  if (data.tokens.searchFontSize === undefined) data.tokens.searchFontSize = 20;
  for (const [key, [min, max]] of Object.entries(dimensions)) {
    if (!bounded(data.tokens[key], min, max))
      throw new Error(`${key} must be between ${min} and ${max}.`);
  }
  if (
    data.tokens.cornerRadius !== undefined &&
    !bounded(data.tokens.cornerRadius, 0, 24)
  )
    throw new Error('cornerRadius must be between 0 and 24.');
  const components = data.components ?? {};
  if (!record(components)) throw new Error('Components must be an object.');
  for (const [component, overrides] of Object.entries(components)) {
    if (!Object.hasOwn(componentFields, component) || !record(overrides))
      throw new Error(`Unknown component: ${component}`);
    const fields: readonly string[] =
      componentFields[component as ComponentName];
    for (const [field, value] of Object.entries(overrides)) {
      if (
        !fields.includes(field) ||
        !(field === 'radius' ? bounded(value, 0, 24) : color(value))
      )
        throw new Error(`Invalid ${component}.${field}`);
    }
  }
  return {
    version: 1,
    id: data.id,
    name: data.name as string,
    author: data.author as string,
    appearance: data.appearance,
    tokens: data.tokens as Theme['tokens'],
    components: components as Theme['components'],
  };
}
export const presets = [graphite, porcelain].map((theme) =>
  parseTheme(JSON.stringify(theme)),
);
const kebab = (value: string) =>
  value.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
export function themeVariables(theme: Theme): Record<string, string> {
  const variables: Record<string, string> = {};
  for (const [key, value] of Object.entries(theme.tokens)) {
    variables[`--${kebab(key)}`] =
      typeof value === 'number' ? `${value}px` : value;
  }
  Object.assign(
    variables,
    radiusVariables(theme.tokens.cornerRadius ?? theme.tokens.shellRadius),
  );
  if (theme.tokens.cornerRadius !== undefined) {
    variables['--shell-radius'] = variables['--radius-window'];
    variables['--row-radius'] = variables['--radius-row'];
  }
  variables['--input-focus-border'] =
    'color-mix(in srgb, var(--accent) 60%, var(--line))';
  for (const [component, fields] of Object.entries(theme.components)) {
    for (const [field, value] of Object.entries(fields)) {
      variables[`--${kebab(component)}-${field}`] =
        typeof value === 'number' ? `${value}px` : value;
    }
  }
  return variables;
}
