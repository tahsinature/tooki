export const noteFonts = [
  {
    value: 'system',
    label: 'System (default)',
    family: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  },
  { value: 'sans', label: 'Sans', family: 'Arial, Helvetica, sans-serif' },
  {
    value: 'serif',
    label: 'Serif',
    family: 'Georgia, "Times New Roman", serif',
  },
  {
    value: 'mono',
    label: 'Mono',
    family: 'ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace',
  },
] as const;
export type NoteFont = (typeof noteFonts)[number]['value'];
export function isNoteFont(value: unknown): value is NoteFont {
  return noteFonts.some((font) => font.value === value);
}
export function noteFontFamily(value: NoteFont) {
  return (
    noteFonts.find((font) => font.value === value)?.family ??
    noteFonts[0].family
  );
}
