import { expect, test } from 'bun:test';
import { matchesNote, noteTitle } from './search';
import { isNoteFont, noteFontFamily } from './fonts';
test('search includes displayed fallback titles and title subsequences', () => {
  const empty = { title: '', text: '' };
  expect(noteTitle(empty)).toBe('Untitled note');
  expect(matchesNote(empty, 'until')).toBe(true);
  expect(matchesNote(empty, ' UNTITLED ')).toBe(true);
  expect(
    matchesNote({ title: '', text: '\nProject review\nmore' }, 'prjrev'),
  ).toBe(true);
  expect(
    matchesNote(
      { title: 'Meeting notes', text: 'Discuss quarterly roadmap' },
      'quarter',
    ),
  ).toBe(true);
  expect(matchesNote(empty, 'nothingmatches')).toBe(false);
});
test('body searches stay literal, and font preferences accept only supported presets', () => {
  expect(
    matchesNote({ title: 'Example', text: '100% saved "quote"' }, '%'),
  ).toBe(true);
  expect(
    matchesNote({ title: 'Example', text: '100% saved "quote"' }, '"quote"'),
  ).toBe(true);
  expect(isNoteFont('mono')).toBe(true);
  expect(isNoteFont('arbitrary')).toBe(false);
  expect(noteFontFamily('mono')).toContain('monospace');
});
