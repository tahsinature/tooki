import {
  Settings,
  Plus,
  Copy,
  Pin,
  PanelsTopLeft,
  Search,
  Clipboard,
  Code,
  Link,
  Download,
  Trash2,
} from '@lucide/svelte';
import type { Note } from './api';
export type NoteCommand =
  | 'settings'
  | 'keep-top'
  | 'new'
  | 'duplicate'
  | 'pin'
  | 'browse'
  | 'browse-trash'
  | 'find'
  | 'copy-text'
  | 'copy-html'
  | 'deeplink'
  | 'export-text'
  | 'export-html'
  | 'export-json'
  | 'trash';
export function noteActions(
  note: Note | undefined,
  mod: string,
  run: (command: NoteCommand) => void,
  keepOnTop = false,
) {
  const entries = [
    {
      id: 'keep-top',
      label: keepOnTop ? 'Stop Keeping on Top' : 'Keep on Top',
      icon: Pin,
      disabled: false,
    },
    {
      id: 'settings',
      label: 'Notes Settings',
      icon: Settings,
      shortcut: `${mod} ,`,
      disabled: false,
    },
    {
      id: 'new',
      label: 'New Note',
      icon: Plus,
      shortcut: `${mod} N`,
      disabled: false,
    },
    {
      id: 'duplicate',
      label: 'Duplicate Note',
      icon: Copy,
      shortcut: `${mod} D`,
    },
    {
      id: 'pin',
      label: note?.pinned ? 'Unpin Note' : 'Pin Note',
      icon: Pin,
      shortcut: `⇧ ${mod} P`,
    },
    {
      id: 'browse',
      label: 'Browse Notes',
      icon: PanelsTopLeft,
      shortcut: `${mod} P`,
      disabled: false,
    },
    { id: 'find', label: 'Find in Note', icon: Search, shortcut: `${mod} F` },
    { id: 'copy-text', label: 'Copy as Plain Text', icon: Clipboard },
    { id: 'copy-html', label: 'Copy as HTML', icon: Code },
    { id: 'deeplink', label: 'Copy Deep Link', icon: Link },
    { id: 'export-text', label: 'Export Plain Text…', icon: Download },
    { id: 'export-html', label: 'Export HTML…', icon: Download },
    { id: 'export-json', label: 'Export Note JSON…', icon: Download },
    { id: 'trash', label: 'Move to Trash', icon: Trash2 },
    {
      id: 'browse-trash',
      label: 'Restore from Trash…',
      icon: Trash2,
      disabled: false,
    },
  ] as const;
  return entries.map((entry) => ({
    ...entry,
    disabled: 'disabled' in entry ? entry.disabled : !note,
    run: () => run(entry.id),
  }));
}
