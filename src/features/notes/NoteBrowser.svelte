<script lang="ts">
  import FilterPopup from '../../components/FilterPopup.svelte';
  import { notesRequest, noteTitle, type Note } from './api';
  let {
    id,
    anchor,
    value,
    deleted = false,
    onchoose,
    onclose,
  }: {
    id: string;
    anchor: HTMLElement;
    value: string;
    deleted?: boolean;
    onchoose: (id: string) => void;
    onclose: (restoreFocus: boolean) => void;
  } = $props();
  async function search(query: string) {
    const notes = await notesRequest<Note[]>('search', { query, deleted });
    return notes.map((note) => ({ value: note.id, label: noteTitle(note) }));
  }
</script>

<FilterPopup
  {id}
  {anchor}
  {value}
  {onclose}
  {onchoose}
  loadOptions={search}
  label={deleted ? 'Restore notes' : 'Browse notes'}
  placeholder={deleted ? 'Search Trash to restore…' : 'Search notes…'}
  emptyMessage={deleted ? 'No deleted notes' : 'No matching notes'}
/>
