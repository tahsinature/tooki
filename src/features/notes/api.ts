import { invoke, isTauri } from '@tauri-apps/api/core';
import type { JSONContent } from '@tiptap/core';
export type Note = {
  id: string;
  title: string;
  document: JSONContent;
  text: string;
  pinned: boolean;
  deleted: boolean;
  updatedAt: number;
  revision: number;
};
export const emptyDocument = (): JSONContent => ({
  type: 'doc',
  content: [{ type: 'paragraph' }],
});
export { noteTitle } from './search';
export async function notesRequest<T>(
  action: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  if (isTauri()) return invoke('notes_request', { action, args });
  const { browserRequest } = await import('./browser-api');
  return browserRequest(action, args) as Promise<T>;
}
export async function openNotes(id?: string, create = false) {
  if (isTauri()) return invoke('open_notes', { id: id ?? null, create });
  window.open(
    `?window=notes${id ? `&note=${encodeURIComponent(id)}` : ''}${create ? '&new=1' : ''}`,
    'tooki-notes',
    'width=460,height=600',
  );
}
export function saveExport(contents: string, format: string) {
  return notesRequest<boolean>('export', { contents, format });
}
