import { expect, test } from 'bun:test';
import { getSchema } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import { findMatches } from './find';
test('find matches span formatting but do not cross separate paragraphs', () => {
  const doc = getSchema([StarterKit]).nodeFromJSON({
    type: 'doc',
    content: [
      {
        type: 'paragraph',
        content: [
          { type: 'text', text: 'Hello ' },
          { type: 'text', text: 'world', marks: [{ type: 'bold' }] },
        ],
      },
      { type: 'paragraph', content: [{ type: 'text', text: 'WORLD again' }] },
    ],
  });
  expect(findMatches(doc, 'hello world')).toEqual([{ from: 1, to: 12 }]);
  expect(findMatches(doc, 'world')).toHaveLength(2);
  expect(findMatches(doc, 'worldworld')).toEqual([]);
  expect(findMatches(doc, '')).toEqual([]);
});
test('find keeps original Unicode positions and treats punctuation literally', () => {
  const doc = getSchema([StarterKit]).nodeFromJSON({
    type: 'doc',
    content: [
      { type: 'paragraph', content: [{ type: 'text', text: 'İ a.b A.B' }] },
    ],
  });
  expect(findMatches(doc, 'a.b')).toEqual([
    { from: 3, to: 6 },
    { from: 7, to: 10 },
  ]);
});
