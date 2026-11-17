<script lang="ts">
  import { onMount, tick, untrack } from 'svelte';
  import { listen } from '@tauri-apps/api/event';
  import { isTauri } from '@tauri-apps/api/core';
  import { startDrag } from '@crabnebula/tauri-plugin-drag';
  import { request, row, position, type Clip } from './api';
  import { preferences } from '../../lib/preferences.svelte';
  import { nextIndex } from '../../lib/navigation';
  import { closeQuickLook, watchQuickLook } from '../../lib/quickLook';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ListDetailPanel from '../../components/ListDetailPanel.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import ClipboardActions from './ClipboardActions.svelte';
  import ClipboardDetail from './ClipboardDetail.svelte';
  let {
    initialFilter = 'all',
    onback,
    onsettings,
  }: {
    initialFilter?: string;
    onback: () => void;
    onsettings: () => void;
  } = $props();
  let query = $state(position.query);
  let filter = $state(
    untrack(() => (initialFilter === 'all' ? position.filter : initialFilter)),
  );
  let selected = $state(preferences.rememberPosition ? position.index : 0);
  let offset = $state(0);
  let total = $state(0);
  let clips = $state<Clip[]>([]);
  let loading = $state(true);
  let status = $state('');
  let actions = $state(false);
  let apps = $state<
    { path: string; name: string; isDefault: boolean }[] | null
  >(null);
  let list = $state<HTMLDivElement>();
  let revision = $state(0);
  let generation = 0;
  let item = $derived(clips[selected - offset]);
  let rows = $derived(clips.map(row));
  async function load(index = selected, preserve = false) {
    const token = ++generation;
    const id = preserve
      ? (item?.id ?? (preferences.rememberPosition ? position.id : undefined))
      : undefined;
    loading = true;
    try {
      const start = Math.floor(Math.max(0, index) / 100) * 100;
      const result = await request<{
        items: Clip[];
        total: number;
        offset: number;
        selected: number | null;
      }>('search', { query, kind: filter, offset: start, anchor: id });
      if (token !== generation) return;
      total = result.total;
      if (total && result.offset >= total) {
        await load(total - 1);
        return;
      }
      offset = result.offset;
      clips = result.items;
      const found = id ? clips.findIndex((c) => c.id === id) : -1;
      selected =
        found >= 0
          ? offset + found
          : Math.min(Math.max(0, index), Math.max(0, total - 1));
      await reveal();
    } catch (e) {
      if (token === generation) status = String(e);
    } finally {
      if (token === generation) loading = false;
    }
  }
  let previewMode = $state<string | undefined>();
  let previewItemId = $state('');
  $effect(() =>
    watchQuickLook('clipboard', (direction) => {
      void select(selected + direction);
    }),
  );
  $effect(() => {
    const id = item?.id;
    if (isTauri() && id)
      void request('previewUpdate', {
        id,
        mode: id === previewItemId ? previewMode : undefined,
      }).catch((e) => (status = String(e)));
  });
  let initial = true;
  $effect(() => {
    query;
    filter;
    generation++;
    const restore = initial && preferences.rememberPosition;
    const index = initial ? untrack(() => selected) : 0;
    initial = false;
    const timer = setTimeout(() => void load(index, restore), 120);
    return () => clearTimeout(timer);
  });
  onMount(() => {
    document.getElementById('search')?.focus();
    if (!isTauri()) {
      status = 'Run the desktop app to access clipboard history.';
      loading = false;
      return;
    }
    let disposed = false;
    const stops: (() => void)[] = [];
    for (const [name, handler] of [
      [
        'clipboard-changed',
        () => {
          revision++;
          void load(selected, true);
        },
      ],
      [
        'clipboard-error',
        (event: { payload: unknown }) => {
          status = String(event.payload);
        },
      ],
    ] as const)
      void listen(name, handler).then((stop) =>
        disposed ? stop() : stops.push(stop),
      );
    return () => {
      disposed = true;
      generation++;
      stops.forEach((stop) => stop());
      position.index = selected;
      position.id = item?.id ?? '';
      position.query = query;
      position.filter = filter;
    };
  });
  async function reveal() {
    await tick();
    if (!list) return;
    if (selected === offset) list.scrollTop = 0;
    else if (selected === offset + clips.length - 1)
      list.scrollTop = list.scrollHeight;
    else
      list
        .querySelector<HTMLElement>(`[data-index="${selected - offset}"]`)
        ?.scrollIntoView({ block: 'nearest' });
  }
  async function select(index: number) {
    selected = Math.max(0, Math.min(total - 1, index));
    if (selected < offset || selected >= offset + clips.length)
      await load(selected);
    else await reveal();
  }
  async function act(operation: string, mode?: string, app?: string) {
    if (!item) return;
    const id = item.id;
    actions = false;
    apps = null;
    status = '';
    try {
      if (operation === 'apps') {
        apps = await request('apps', { id });
        actions = true;
      } else if (operation === 'drag') {
        const data = await request<{ paths: string[]; icon: string }>('drag', {
          id,
        });
        await startDrag({ item: data.paths, icon: data.icon, mode: 'copy' });
      } else {
        if (operation === 'preview') {
          previewMode = mode;
          previewItemId = id;
        }
        await request(operation, { id, mode, app });
        if (operation === 'copy') status = 'Copied to clipboard';
        if (['copy', 'pin', 'delete', 'retryOcr'].includes(operation))
          document.getElementById('search')?.focus();
      }
    } catch (e) {
      status = String(e);
    }
  }
  async function toggleActions() {
    actions = !actions;
    apps = null;
    await tick();
    if (actions)
      document.querySelector<HTMLInputElement>('.actions-search')?.focus();
    else document.getElementById('search')?.focus();
  }
  function resetSearch() {
    // Invalidate the old results immediately, including their remembered anchor.
    // A second Escape may leave this view before the next search has finished.
    generation++;
    query = '';
    filter = initialFilter;
    selected = 0;
    offset = 0;
    total = 0;
    clips = [];
    loading = true;
    status = '';
    apps = null;
    previewMode = undefined;
    previewItemId = '';
    void closeQuickLook('clipboard').catch((error) => (status = String(error)));
    document.getElementById('search')?.focus();
  }
  function beginDrag(event: PointerEvent) {
    if (event.button !== 0) return;
    const x = event.clientX,
      y = event.clientY;
    function cleanup() {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', cleanup);
      window.removeEventListener('pointercancel', cleanup);
    }
    function move(next: PointerEvent) {
      if (Math.hypot(next.clientX - x, next.clientY - y) < 4) return;
      cleanup();
      void act('drag');
    }
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', cleanup, { once: true });
    window.addEventListener('pointercancel', cleanup, { once: true });
  }
  function keyboard(e: KeyboardEvent) {
    if (
      e.defaultPrevented ||
      e.isComposing ||
      document.querySelector('dialog[open]')
    )
      return;
    const cmd = e.metaKey;
    if (e.key === 'Escape') {
      e.preventDefault();
      if (!cmd && actions) {
        actions = false;
        apps = null;
        document.getElementById('search')?.focus();
      } else if (!cmd && (query || filter !== initialFilter)) {
        resetSearch();
      } else onback();
      return;
    }
    if (cmd && e.key === ',') {
      e.preventDefault();
      onsettings();
      return;
    }
    if (cmd && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      void toggleActions();
      return;
    }
    if (actions) return;
    if (cmd && ['y', 'o'].includes(e.key.toLowerCase())) {
      e.preventDefault();
      void act(e.key.toLowerCase() === 'y' ? 'preview' : 'apps');
      return;
    }
    if (cmd && e.shiftKey && e.key.toLowerCase() === 'p') {
      e.preventDefault();
      void act('pin');
      return;
    }
    if (e.ctrlKey && e.key.toLowerCase() === 'x') {
      e.preventDefault();
      void act('delete');
      return;
    }
    if (
      e.key === 'Enter' &&
      (cmd || (e.target as HTMLElement).tagName === 'INPUT')
    ) {
      e.preventDefault();
      void act(cmd ? 'paste' : 'copy');
      return;
    }
    if (['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown'].includes(e.key)) {
      e.preventDefault();
      void select(
        nextIndex(
          e.key,
          selected,
          total,
          Math.max(1, Math.floor((list?.clientHeight ?? 360) / 38) - 1),
          cmd,
        ),
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
    />{/snippet}
  <ListDetailPanel detail={preview}>
    <div class="clipboard-list-column">
      <GroupedPanelList
        items={rows}
        group={(r) =>
          r.pinned ? 'Pinned' : preferences.groupByDate ? r.group : ''}
        label="Clipboard items"
        bind:element={list}
      >
        {#snippet row(r, index)}<ResultRow
            item={r}
            {index}
            selected={offset + index === selected}
            onclick={() => (selected = offset + index)}
            onopen={() => {
              selected = offset + index;
              void act('copy');
            }}
          />{/snippet}
        {#snippet empty()}<EmptyState
            title={loading
              ? 'Loading clipboard…'
              : query
                ? 'No matching clips'
                : 'Your clipboard is empty'}
            description="Copy text, images, or files to collect them here."
          />{/snippet}
      </GroupedPanelList>
      {#if total > 100}<nav
          class="clipboard-paging"
          aria-label="Clipboard pages"
        >
          <button
            disabled={offset === 0}
            onclick={() => void select(offset - 1)}>Previous</button
          ><span>{offset + 1}–{offset + clips.length} of {total}</span><button
            disabled={offset + clips.length >= total}
            onclick={() => void select(offset + clips.length)}>Next</button
          >
        </nav>{/if}
    </div>
  </ListDetailPanel>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      count={total}
      selectedIndex={item ? selected : -1}
      {status}
      ondrag={beginDrag}
      onprimary={() => void act('copy')}
      onactions={() => void toggleActions()}
      disabled={!item}
      {onsettings}
    />{/snippet}
  {#snippet overlay()}
    {#if actions && item}<ClipboardActions
        {item}
        {apps}
        {act}
        onclose={() => {
          actions = false;
          apps = null;
        }}
      />{/if}
  {/snippet}
</PanelLayout>
{#snippet preview()}<ClipboardDetail id={item?.id} {revision} />{/snippet}
