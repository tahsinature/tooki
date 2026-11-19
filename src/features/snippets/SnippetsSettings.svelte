<script lang="ts">
  import { snippetDraft } from './draft.svelte';
  import { onMount } from 'svelte';
  import { listen } from '@tauri-apps/api/event';
  import {
    request,
    create,
    row as snippetRow,
    type Record,
    type Library,
  } from './api';
  import SearchField from '../../components/SearchField.svelte';
  import Button from '../../components/Button.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import ConfirmationActions from '../../components/ConfirmationActions.svelte';
  import SnippetEditor from './SnippetEditor.svelte';
  import ExpansionSettings from './ExpansionSettings.svelte';
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import './snippets.css';
  let library = $state<Library>();
  let query = $state(''),
    error = $state('');
  let confirmation = $state<'discard' | 'delete' | null>(null);
  let visible = $derived(
    (library?.records ?? []).filter((record) =>
      `${record.definition.name} ${record.configuration.trigger} ${record.definition.collection}`
        .toLowerCase()
        .includes(query.toLowerCase()),
    ),
  );
  async function refresh() {
    try {
      library = await request<Library>('list');
    } catch (reason) {
      error = String(reason);
    }
  }
  function edit(record: Record) {
    snippetDraft.record = JSON.parse(JSON.stringify(record));
    snippetDraft.baseline = JSON.stringify(snippetDraft.record);
  }
  function cancel() {
    if (JSON.stringify(snippetDraft.record) !== snippetDraft.baseline)
      confirmation = 'discard';
    else snippetDraft.record = undefined;
  }
  onMount(() => {
    void refresh();
    let disposed = false;
    let stop: (() => void) | undefined;
    void listen('snippets-changed', () => void refresh()).then((fn) => {
      if (disposed) fn();
      else stop = fn;
    });
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

{#if error}<p class="error-message" role="alert">{error}</p>{/if}
{#if snippetDraft.record}
  <SnippetEditor
    bind:record={snippetDraft.record}
    onsaved={() => {
      snippetDraft.record = undefined;
      void refresh();
    }}
    oncancel={cancel}
  />
  {#if snippetDraft.record?.revision}<div class="snippet-delete">
      <Button destructive onclick={() => (confirmation = 'delete')}
        >Delete Snippet</Button
      >
    </div>{/if}
{:else}
  <div class="snippet-section-heading">
    <div>
      <h2>Your Snippets</h2>
      <p class="snippet-hint">
        Start with text, a date, a choice list, or a template with inputs.
      </p>
    </div>
  </div>
  <div class="snippet-starters">
    <Button onclick={() => edit(create('text'))}>Text</Button><Button
      onclick={() => edit(create('text', true))}>Current Date</Button
    ><Button onclick={() => edit(create('choice'))}>Choice List</Button><Button
      onclick={() => edit(create('template'))}>Template with Inputs</Button
    >
  </div>
  <SearchField
    bind:value={query}
    label="Search snippets"
    placeholder="Search your snippets…"
  />
  <div class="snippet-library">
    <GroupedPanelList
      items={visible.map(snippetRow)}
      group={(item) => item.group}
      label="Saved snippets"
    >
      {#snippet row(item, index)}<ResultRow
          {item}
          {index}
          selected={false}
          onclick={() => edit(visible[index])}
          onopen={() => edit(visible[index])}
        />{/snippet}
      {#snippet empty()}<EmptyState
          title={query
            ? 'No matching snippets'
            : 'Your first snippet starts here'}
          description={query
            ? 'Try another name or trigger.'
            : 'Choose Current Date to create $today, or Choice List for @email-1 and @email-2.'}
        />{/snippet}
    </GroupedPanelList>
  </div>
  {#if library}<ExpansionSettings {library} onrefresh={refresh} />{/if}
  <ToolCommands tool="snippets" />
{/if}
{#if confirmation}<ConfirmationActions
    title={confirmation === 'delete' ? 'Delete snippet?' : 'Discard changes?'}
    description={confirmation === 'delete'
      ? 'This removes the snippet and its personal values from Tooki.'
      : 'Your unsaved changes will be lost.'}
    confirmLabel={confirmation === 'delete' ? 'Delete Snippet' : 'Discard'}
    onclose={() => (confirmation = null)}
    onconfirm={async () => {
      if (confirmation === 'delete' && snippetDraft.record)
        await request('delete', {
          id: snippetDraft.record.definition.id,
          revision: snippetDraft.record.revision,
        });
      confirmation = null;
      snippetDraft.record = undefined;
      await refresh();
    }}
  />{/if}
