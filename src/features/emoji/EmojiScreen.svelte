<script lang="ts">
  import { onMount, tick, untrack } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Copy, ClipboardPaste, Text, Smile } from '@lucide/svelte';
  import { sections, gridRows, move, position, type Library } from './model';
  import { preferences } from '../../lib/preferences.svelte';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import SectionHeader from '../../components/SectionHeader.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import './emoji.css';
  let { onback, onsettings }: { onback: () => void; onsettings: () => void } =
    $props();
  let library = $state<Library>({
    items: [],
    groups: [],
    recent: [],
    canPaste: false,
  });
  let query = $state(position.query),
    filter = $state(position.filter);
  let selected = $state(0),
    loading = $state(true),
    busy = $state(false),
    actions = $state(false),
    status = $state('');
  let list = $state<HTMLDivElement>();
  let rows = $derived(gridRows(sections(library, query, filter)));
  let cells = $derived(rows.flatMap((row) => row.cells));
  let item = $derived(cells[selected]?.item);
  $effect(() => {
    query;
    filter;
    selected = 0;
    status = '';
  });
  $effect(() => {
    selected;
    rows;
    void tick().then(() => {
      if (selected === 0) list?.scrollTo({ top: 0 });
      else
        list
          ?.querySelector(`[data-emoji-index="${selected}"]`)
          ?.scrollIntoView({ block: 'nearest' });
    });
  });
  onMount(() => {
    let disposed = false;
    document.getElementById('search')?.focus();
    void invoke<Library>('emoji_request', { operation: 'list' })
      .then(async (result) => {
        if (disposed) return;
        library = result;
        await tick();
        if (preferences.rememberPosition)
          selected = Math.max(
            0,
            cells.findIndex((cell) => cell.id === position.selection),
          );
      })
      .catch((error) => (status = String(error)))
      .finally(() => (loading = false));
    return () => {
      disposed = true;
      position.query = query;
      position.filter = filter;
      position.selection = untrack(() => cells[selected]?.id ?? '');
    };
  });
  async function run(operation = 'copy') {
    if (!item || busy) return;
    busy = true;
    actions = false;
    status = '';
    try {
      await invoke('emoji_request', { operation, character: item.character });
    } catch (error) {
      status = String(error);
    } finally {
      busy = false;
    }
  }
  function keyboard(event: KeyboardEvent) {
    if (
      event.defaultPrevented ||
      event.isComposing ||
      document.querySelector('dialog[open]')
    )
      return;
    const command = event.metaKey || event.ctrlKey;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (command) {
        void invoke('dismiss_launcher');
        return;
      }
      if (actions) actions = false;
      else if (query || filter !== 'all') {
        query = '';
        filter = 'all';
        selected = 0;
      } else onback();
      document.getElementById('search')?.focus();
      return;
    }
    if (command && event.key === ',') {
      event.preventDefault();
      onsettings();
      return;
    }
    if (command && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      if (item) actions = !actions;
      return;
    }
    if (actions) return;
    if (
      event.key === 'Enter' &&
      (event.target as HTMLElement)?.id === 'search'
    ) {
      event.preventDefault();
      if (!event.repeat) void run(command ? 'paste' : 'copy');
    } else if (
      [
        'ArrowLeft',
        'ArrowRight',
        'ArrowUp',
        'ArrowDown',
        'PageUp',
        'PageDown',
        'Home',
        'End',
      ].includes(event.key) &&
      (event.target as HTMLElement)?.id === 'search'
    ) {
      event.preventDefault();
      selected = move(
        rows,
        selected,
        event.key,
        Math.max(1, Math.floor((list?.clientHeight ?? 420) / 60) - 1),
        command,
      );
    }
  }
</script>

<svelte:window onkeydown={keyboard} />
<PanelLayout>
  {#snippet header()}<SearchHeader
      bind:query
      bind:filter
      clipboard={true}
      {onback}
      placeholder="Search emoji…"
      filterOptions={[
        { value: 'all', label: 'All Emoji' },
        { value: 'recent', label: 'Recently Used' },
        ...library.groups.map((group) => ({ value: group, label: group })),
      ]}
    />{/snippet}
  <div class="emoji-list result-list" bind:this={list} aria-label="Emoji">
    {#each rows as row (row.cells[0].id)}
      {#if row.heading}<SectionHeader title={row.heading} />{/if}
      <div class="emoji-grid-row">
        {#each row.cells as cell (cell.id)}
          <button
            class="emoji-cell"
            class:selected={selected === cell.index}
            data-emoji-index={cell.index}
            aria-label={`${cell.item.name} :${cell.item.shortcode}:`}
            aria-current={selected === cell.index ? 'true' : undefined}
            title={cell.item.name}
            disabled={busy}
            onmousedown={(event) => event.preventDefault()}
            onclick={() => {
              selected = cell.index;
              void run();
            }}
          >
            {cell.item.character}
          </button>
        {/each}
      </div>
    {:else}<EmptyState
        title={loading
          ? 'Loading emoji…'
          : query
            ? 'No matching emoji'
            : 'No recent emoji'}
        description={status ||
          (loading ? '' : 'Search by name, keyword, or shortcode.')}
      />{/each}
  </div>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      toolIcon={Smile}
      count={cells.length}
      selectedIndex={selected}
      status={status || item?.name || ''}
      primaryLabel="Copy Emoji"
      disabled={!item || busy}
      onprimary={() => void run()}
      onactions={() => (actions = !actions)}
      {onsettings}
    />{/snippet}
  {#snippet overlay()}{#if actions && item}<PopupSurface
        title={`${item.character} ${item.name}`}
        onclose={() => (actions = false)}
      >
        <ActionsMenu
          actions={[
            {
              id: 'copy',
              label: 'Copy Emoji',
              icon: Copy,
              shortcut: '↵',
              run: () => void run(),
            },
            {
              id: 'paste',
              label: 'Paste Emoji',
              icon: ClipboardPaste,
              shortcut: '⌘↵',
              disabled: !library.canPaste,
              run: () => void run('paste'),
            },
            {
              id: 'shortcode',
              label: 'Copy Shortcode',
              icon: Text,
              run: () => void run('shortcode'),
            },
          ]}
        />
      </PopupSurface>{/if}{/snippet}
</PanelLayout>
