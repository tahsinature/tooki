import { describe, expect, test } from 'bun:test';
import { parseTheme, presets, themeVariables } from './theme';
const source = () => structuredClone(presets[0]);
describe('portable themes', () => {
  test('both presets round-trip with complete tokens', () => {
    for (const theme of presets)
      expect(parseTheme(JSON.stringify(theme))).toEqual(theme);
  });
  test('component overrides use scoped variables', () => {
    const theme = source();
    theme.components = { resultRow: { radius: 8, selected: '#abcdef' } };
    const variables = themeVariables(parseTheme(JSON.stringify(theme)));
    expect(variables['--result-row-selected']).toBe('#abcdef');
    expect(variables['--result-row-radius']).toBe('8px');
    expect(variables['--row-height']).toBe('38px');
  });
  test('one corner radius scales windows and controls, including square corners', () => {
    const theme = source();
    theme.tokens.cornerRadius = 9;
    const variables = themeVariables(theme);
    expect(variables['--shell-radius']).toBe('9px');
    expect(variables['--row-radius']).toBe('4px');
    expect(variables['--radius-control']).toBe('3px');
    theme.tokens.cornerRadius = 0;
    for (const [key, value] of Object.entries(themeVariables(theme))) {
      if (key.startsWith('--radius-')) expect(value).toBe('0px');
    }
  });
  test('legacy theme sizes and explicit component overrides stay compatible', () => {
    const theme = source();
    delete theme.tokens.cornerRadius;
    theme.tokens.shellRadius = 20;
    theme.tokens.rowRadius = 5;
    const variables = themeVariables(parseTheme(JSON.stringify(theme)));
    expect(variables['--shell-radius']).toBe('20px');
    expect(variables['--row-radius']).toBe('5px');
    expect(variables['--radius-window']).toBe('20px');
    theme.tokens.cornerRadius = 12;
    theme.components = { popup: { radius: 3 } };
    expect(themeVariables(theme)['--popup-radius']).toBe('3px');
  });
  test('rejects injection, remote resources, unknown slots and unsafe sizes', () => {
    for (const value of [
      'url(https://example.com)',
      'red;display:none',
      '#fff',
    ]) {
      const theme = source();
      theme.tokens.surface = value;
      expect(() => parseTheme(JSON.stringify(theme))).toThrow();
    }
    for (const rowHeight of [0, 500, '38px']) {
      const theme = { ...source(), tokens: { ...source().tokens, rowHeight } };
      expect(() => parseTheme(JSON.stringify(theme))).toThrow();
    }
    for (const cornerRadius of [-1, 25, '18px', null]) {
      const theme = {
        ...source(),
        tokens: { ...source().tokens, cornerRadius },
      };
      expect(() => parseTheme(JSON.stringify(theme))).toThrow();
    }
    expect(() =>
      parseTheme(
        JSON.stringify({
          ...source(),
          components: { body: { display: 'none' } },
        }),
      ),
    ).toThrow();
    expect(() =>
      parseTheme(
        JSON.stringify({
          ...source(),
          components: { resultRow: { radius: -1 } },
        }),
      ),
    ).toThrow();
  });
  test('rejects incomplete, unsupported and oversized themes', () => {
    for (const invalid of [
      null,
      [],
      { version: 2 },
      { ...source(), tokens: {} },
      { ...source(), id: '../test' },
    ])
      expect(() => parseTheme(JSON.stringify(invalid))).toThrow();
    expect(() => parseTheme(' '.repeat(32_001))).toThrow();
  });
});

test('search text size survives sharing and older themes keep 20px', () => {
  const theme = source();
  theme.tokens.searchFontSize = 26;
  expect(
    themeVariables(parseTheme(JSON.stringify(theme)))['--search-font-size'],
  ).toBe('26px');
  const legacy = JSON.parse(JSON.stringify(theme));
  delete legacy.tokens.searchFontSize;
  expect(parseTheme(JSON.stringify(legacy)).tokens.searchFontSize).toBe(20);
  for (const value of [0, 29, '20px', null]) {
    legacy.tokens.searchFontSize = value;
    expect(() => parseTheme(JSON.stringify(legacy))).toThrow();
  }
});
