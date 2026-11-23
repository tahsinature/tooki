<script lang="ts">
  import FilterPopup from '../../components/FilterPopup.svelte';
  import { notesRequest, noteTitle, type Note } from './api';
  let {
    id,
    anchor,
    value,
    deleted = false,
    onchoose,
    onpreview,
    onclose,
  }: {
    id: string;
    anchor: HTMLElement;
    value: string;
    deleted?: boolean;
    onchoose: (id: string) => void;
    onpreview: (note: Note | undefined) => void;
    onclose: (restoreFocus: boolean) => void;
  } = $props();
  const available = new Map<string, Note>();
  async function search(query: string) {
    const notes = await notesRequest<Note[]>('search', { query, deleted });
    for (const note of notes) available.set(note.id, note);
    return notes.map((note) => ({ value: note.id, label: noteTitle(note) }));
  }
</script>

<FilterPopup
  {id}
  placement="window"
  {anchor}
  {value}
  {onclose}
  {onchoose}
  onhighlight={(id) => onpreview(id ? available.get(id) : undefined)}
  loadOptions={search}
  label={deleted ? 'Restore notes' : 'Browse notes'}
  placeholder={deleted ? 'Search Trash to restore…' : 'Search notes…'}
  emptyMessage={deleted ? 'No deleted notes' : 'No matching notes'}
/>
