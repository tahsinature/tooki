import { expect, test } from 'bun:test';
import { Autosave, type Draft } from './autosave';
import { emptyDocument, type Note } from './api';
const note: Note = {
  id: 'one',
  title: 'Original',
  document: emptyDocument(),
  text: '',
  pinned: false,
  deleted: false,
  updatedAt: 0,
  revision: 0,
};
test('edits arriving during a save are written afterward using the new revision', async () => {
  const calls: Draft[] = [];
  let release!: (note: Note) => void;
  let stored: Draft | undefined;
  const save = new Autosave(
    note,
    async (draft) => {
      calls.push(draft);
      if (calls.length === 1)
        return new Promise<Note>((resolve) => (release = resolve));
      return { ...note, ...draft, revision: draft.revision + 1 };
    },
    { write: (draft) => (stored = draft), clear: () => (stored = undefined) },
    () => {},
  );
  save.update({ ...note, title: 'First' });
  const flushing = save.flush();
  save.update({ ...note, title: 'Latest' });
  expect(calls).toHaveLength(1);
  release({ ...note, title: 'First', revision: 1 });
  await flushing;
  expect(calls.map((d) => [d.title, d.revision])).toEqual([
    ['First', 0],
    ['Latest', 1],
  ]);
  expect(stored).toBeUndefined();
  expect(save.currentRevision).toBe(2);
  save.dispose();
});
test('failed writes retain recovery data, reject flush, and can be retried', async () => {
  let fail = true;
  let stored: Draft | undefined;
  const states: string[] = [];
  const save = new Autosave(
    note,
    async (draft) => {
      if (fail) throw new Error('Disk full');
      return { ...note, ...draft, revision: 1 };
    },
    { write: (d) => (stored = d), clear: () => (stored = undefined) },
    (state) => states.push(state),
  );
  save.update({ ...note, title: 'Keep this' });
  await expect(save.flush()).rejects.toThrow('Disk full');
  expect(stored?.title).toBe('Keep this');
  expect(states.at(-1)).toBe('error');
  fail = false;
  await save.flush();
  expect(stored).toBeUndefined();
  expect(states.at(-1)).toBe('saved');
  save.dispose();
});
