// Browser previews use an isolated store. Desktop Notes always uses Rust/SQLite.
import { matchesNote } from './search';
import { emptyDocument, type Note } from './api';
import type { JSONContent } from '@tiptap/core';
const key = 'tooki-browser-notes-v1';
function text(node: JSONContent): string {
  return (
    (node.text ?? '') +
    (node.content?.map(text).join('') ?? '') +
    (['paragraph', 'heading', 'codeBlock', 'hardBreak'].includes(
      node.type ?? '',
    )
      ? '\n'
      : '')
  );
}
export async function browserRequest(
  action: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const notes: Note[] = JSON.parse(localStorage.getItem(key) ?? '[]');
  const note = notes.find((n) => n.id === args.id);
  if (action === 'search')
    return notes
      .filter(
        (n) =>
          n.deleted === !!args.deleted &&
          matchesNote(n, String(args.query ?? '')),
      )
      .sort(
        (a, b) =>
          Number(b.pinned) - Number(a.pinned) || b.updatedAt - a.updatedAt,
      );
  if (action === 'lastNote') return localStorage.getItem(`${key}-last`);
  if (action === 'takeRequest') return null;
  if (action === 'hide') {
    window.close();
    return null;
  }
  if (action === 'export') {
    const url = URL.createObjectURL(
      new Blob([String(args.contents)], { type: 'text/plain;charset=utf-8' }),
    );
    const link = document.createElement('a');
    link.href = url;
    link.download = `note.${args.format}`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    return true;
  }
  if (action === 'create') {
    const document = (args.document ?? emptyDocument()) as JSONContent;
    const created: Note = {
      id: crypto.randomUUID().replaceAll('-', ''),
      title: String(args.title ?? defaultNoteTitle()),
      document,
      text: text(document).trimEnd(),
      pinned: false,
      deleted: false,
      updatedAt: Date.now(),
      revision: 0,
    };
    notes.push(created);
    localStorage.setItem(key, JSON.stringify(notes));
    return created;
  }
  if (!note) throw new Error('Note not found.');
  if (action === 'get') {
    localStorage.setItem(`${key}-last`, note.id);
    return note;
  }
  if (action === 'save') {
    if (note.deleted || note.revision !== args.revision)
      throw new Error('This note changed. Your draft has been kept.');
    note.title = String(args.title ?? '').slice(0, 200);
    note.document = args.document as JSONContent;
    note.text = text(note.document).trimEnd();
    note.updatedAt = Date.now();
  } else if (action === 'pin') note.pinned = !!args.value;
  else if (action === 'trash') note.deleted = true;
  else if (action === 'restore') note.deleted = false;
  else throw new Error('Unknown Notes action');
  note.revision++;
  localStorage.setItem(key, JSON.stringify(notes));
  return note;
}

function defaultNoteTitle() {
  const date = new Date();
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}_${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}__note`;
}
