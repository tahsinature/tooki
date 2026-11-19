<script lang="ts">
  import TextInput from '../../components/TextInput.svelte';
  import { onMount, tick } from 'svelte';
  import { watchQuickLook } from '../../lib/quickLook';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { dragShelfItems } from './drag';
  import { FolderOpen } from '@lucide/svelte';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ListDetailPanel from '../../components/ListDetailPanel.svelte';
  import DetailLayout from '../../components/DetailLayout.svelte';
  import InformationList from '../../components/InformationList.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import ShelfConversion from './ShelfConversion.svelte';
  import ShelfActions from './ShelfActions.svelte';
  import ConfirmationActions from '../../components/ConfirmationActions.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import Button from '../../components/Button.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import type { Item } from '../../lib/data';
  import { request, type Library } from './api';
  let {
    onback = () => {},
    onsettings = () => {
      if (isTauri()) void invoke('open_settings');
    },
  }: { onback?: () => void; onsettings?: () => void } = $props();
  const fixedShelf = new URLSearchParams(location.search).get('shelf');
  let shelfId = $state(fixedShelf ?? '');
  let library = $state<Library>({
    shelves: [],
    settings: {
      enabled: true,
      showOnShiftDrag: false,
      removeAfterDragOut: false,
    },
    shelfCapabilities: { shiftDrag: false, shiftDragReason: '' },
    capabilities: { nativePreview: false, openWith: false, copyFiles: false },
  });
  let query = $state(''),
    filter = $state('all'),
    selected = $state(0),
    actions = $state(false),
    status = $state('');
  let dialog = $state(''),
    name = $state(''),
    busy = $state(false);
  let confirmation = $state<{
    title: string;
    description: string;
    label: string;
    operation: string;
    args: Record<string, unknown>;
  } | null>(null);
  let apps = $state<
    { name: string; path: string; isDefault: boolean }[] | null
  >(null);
  let itemDetail = $state<{
    exists: boolean;
    bytes: number | null;
    text: string | null;
    image: string | null;
  } | null>(null);
  let shelf = $derived(library.shelves.find((s) => s.id === shelfId));
  let rows = $derived(
    (shelf
      ? shelf.items.map((i) => ({
          id: i.id,
          title: i.name,
          subtitle: i.path,
          kind: 'file',
          group: i.owned ? 'Copies' : 'References',
          content: i.path,
          source: '',
          time: '',
        }))
      : library.shelves.map((s) => ({
          id: s.id,
          title: s.name,
          subtitle: `${s.items.length} ${s.items.length === 1 ? 'item' : 'items'}`,
          kind: 'file',
          group: 'Shelves',
          content: '',
          source: '',
          time: '',
        }))
    ).filter(
      (i) =>
        i.title.toLowerCase().includes(query.toLowerCase()) &&
        (!shelf ||
          filter === 'all' ||
          (filter === 'copies'
            ? i.group === 'Copies'
            : i.group === 'References')),
    ) as Item[],
  );
  let row = $derived(rows[selected]);
  let current = $derived(shelf?.items.find((i) => i.id === row?.id));
  $effect(() => {
    query;
    filter;
    shelfId;
    selected = 0;
    actions = false;
  });
  $effect(() => {
    if (selected >= rows.length) selected = Math.max(0, rows.length - 1);
  });
  $effect(() => {
    const item = current;
    itemDetail = null;
    let cancelled = false;
    if (item)
      void request<typeof itemDetail>('detail', {
        shelf: shelfId,
        item: item.id,
      })
        .then((value) => {
          if (!cancelled) itemDetail = value;
        })
        .catch((e) => {
          if (!cancelled) status = String(e);
        });
    return () => {
      cancelled = true;
    };
  });
  const previewContext = $derived(shelf ? `shelf:${shelf.id}` : '');
  $effect(() =>
    watchQuickLook(previewContext, (direction) => {
      selected = Math.max(0, Math.min(rows.length - 1, selected + direction));
    }),
  );
  $effect(() => {
    const id = current?.id;
    const target = shelf?.id;
    if (isTauri() && target && library.capabilities.nativePreview)
      void request('previewUpdate', {
        shelf: target,
        items: id ? [id] : [],
      }).catch((e) => (status = String(e)));
  });
  async function refresh() {
    try {
      library = await request<Library>('list');
    } catch (e) {
      status = String(e);
    }
  }
  onMount(() => {
    void refresh();
    void tick().then(() => document.getElementById('search')?.focus());
    if (!isTauri()) return;
    let disposed = false;
    const stops: (() => void)[] = [];
    void listen('shelf-changed', () => void refresh()).then((stop) =>
      disposed ? stop() : stops.push(stop),
    );
    void getCurrentWindow()
      .onDragDropEvent((event) => {
        if (event.payload.type === 'drop' && shelfId)
          void perform('addFiles', { paths: event.payload.paths, copy: false });
      })
      .then((stop) => (disposed ? stop() : stops.push(stop)));
    return () => {
      disposed = true;
      stops.forEach((stop) => stop());
    };
  });
  function back() {
    if (shelfId && !fixedShelf) {
      shelfId = '';
      query = '';
    } else onback();
  }
  async function perform(
    operation: string,
    args: Record<string, unknown> = {},
  ) {
    actions = false;
    busy = true;
    status = '';
    try {
      const target = shelfId || row?.id;
      if (operation === 'convert') {
        dialog = 'convert';
      } else if (operation === 'apps') {
        apps = await request('apps', { shelf: target, item: row?.id });
        actions = true;
      } else if (operation === 'drag' && current) {
        await dragShelfItems(
          target,
          current.id,
          (message) => (status = message),
        );
      } else {
        await request(operation, { shelf: target, item: row?.id, ...args });
        dialog = '';
        await refresh();
      }
    } catch (e) {
      status = String(e);
    } finally {
      busy = false;
    }
  }
  function open() {
    if (shelf) void perform('open');
    else if (row) {
      shelfId = row.id;
      query = '';
    }
  }
  function edit(operation: string) {
    actions = false;
    if ((operation === 'remove' || operation === 'deleteShelf') && row) {
      const deletingShelf = operation === 'deleteShelf';
      const owned = deletingShelf
        ? library.shelves
            .find((entry) => entry.id === row.id)
            ?.items.some((item) => item.owned)
        : current?.owned;
      confirmation = {
        title: deletingShelf
          ? `Delete “${row.title}”?`
          : `Remove “${row.title}”?`,
        description: owned
          ? 'Tooki-owned copies will be deleted. Original files stay untouched.'
          : 'Original files stay untouched.',
        label: deletingShelf
          ? owned
            ? 'Delete Shelf and Copies'
            : 'Delete Shelf'
          : owned
            ? 'Remove and Delete Copy'
            : 'Remove from Shelf',
        operation,
        args: { shelf: shelfId || row.id, item: row.id },
      };
      return;
    }
    dialog = operation;
    name = operation === 'create' ? 'New Shelf' : (row?.title ?? '');
  }
  function keyboard(e: KeyboardEvent) {
    if (
      confirmation ||
      e.defaultPrevented ||
      document.querySelector('dialog[open]') ||
      e.isComposing
    )
      return;
    const cmd = e.metaKey || e.ctrlKey;
    if (cmd && e.key === ',') {
      e.preventDefault();
      onsettings();
      return;
    }
    if (cmd && e.key === 'Escape') {
      e.preventDefault();
      if (!fixedShelf) onback();
      return;
    }
    if (e.key === 'Escape') {
      e.preventDefault();
      if (actions) {
        actions = false;
        apps = null;
        document.getElementById('search')?.focus();
      } else back();
      return;
    }
    if (cmd && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      apps = null;
      actions = !actions;
      return;
    }
    if (actions) return;
    if (cmd && e.key.toLowerCase() === 'v' && shelf) {
      e.preventDefault();
      void perform('paste');
      return;
    }
    if (cmd && e.key.toLowerCase() === 's') {
      e.preventDefault();
      void perform('toggleAll');
      return;
    }
    if (cmd && e.key.toLowerCase() === 'y' && current) {
      e.preventDefault();
      void perform('preview');
      return;
    }
    if (cmd && e.key.toLowerCase() === 'n') {
      e.preventDefault();
      edit('create');
      return;
    }
    if (['ArrowDown', 'ArrowUp'].includes(e.key)) {
      e.preventDefault();
      selected = Math.max(
        0,
        Math.min(rows.length - 1, selected + (e.key === 'ArrowDown' ? 1 : -1)),
      );
      void tick().then(() =>
        document
          .querySelector(`[data-index="${selected}"]`)
          ?.scrollIntoView({ block: 'nearest' }),
      );
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      open();
    }
  }
</script>

<svelte:window onkeydown={keyboard} />
<PanelLayout>
  {#snippet header()}<SearchHeader
      bind:query
      bind:filter
      clipboard={true}
      placeholder={shelf ? `Search ${shelf.name}…` : 'Search shelves…'}
      filterOptions={shelf
        ? [
            { value: 'all', label: 'All items' },
            { value: 'references', label: 'References' },
            { value: 'copies', label: 'Copies' },
          ]
        : [{ value: 'all', label: 'All shelves' }]}
      onback={fixedShelf ? undefined : back}
    />{/snippet}
  <ListDetailPanel detail={fixedShelf ? undefined : preview}>
    <GroupedPanelList
      items={rows}
      label="Shelf items"
      group={(item) => item.group}
    >
      {#snippet row(item, index)}<ResultRow
          {item}
          {index}
          selected={index === selected}
          onclick={() => (selected = index)}
          onactions={() => {
            apps = null;
            actions = true;
          }}
          onopen={() => {
            selected = index;
            open();
          }}
        />{/snippet}
      {#snippet empty()}<EmptyState
          title={shelf ? 'This shelf is empty' : 'No shelves yet'}
          description={shelf
            ? 'Drop files here or use Actions to add files or clipboard text.'
            : 'Open Actions to create a shelf.'}
        />{/snippet}
    </GroupedPanelList>
  </ListDetailPanel>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      count={rows.length}
      selectedIndex={selected}
      {status}
      primaryLabel="Open"
      secondaryAction={{
        label: 'Show/Hide All',
        shortcut: 'CommandOrControl+KeyS',
        disabled: busy,
        run: () => void perform('toggleAll'),
      }}
      disabled={busy}
      onprimary={open}
      onactions={() => {
        if (confirmation) {
          confirmation = null;
          return;
        }
        apps = null;
        actions = !actions;
      }}
      {onsettings}
    />{/snippet}
  {#snippet overlay()}{#if confirmation}
      <ConfirmationActions
        title={confirmation.title}
        description={confirmation.description}
        confirmLabel={confirmation.label}
        onclose={() => (confirmation = null)}
        onconfirm={async () => {
          const pending = confirmation;
          if (!pending) return;
          await perform(pending.operation, pending.args);
          confirmation = null;
        }}
      />
    {/if}{#if actions}<ShelfActions
        {shelf}
        {row}
        {current}
        {apps}
        capabilities={library.capabilities}
        canConvert={!!library.imageConversion}
        {open}
        {perform}
        {edit}
        onclose={() => (actions = false)}
      />{/if}
    {#if dialog === 'convert' && current}<Dialog
        title="Convert image"
        onclose={() => (dialog = '')}
        ><ShelfConversion
          shelf={shelfId}
          items={[current.id]}
          onclose={() => (dialog = '')}
          onsaved={() => void refresh()}
        /></Dialog
      >{:else if dialog}<Dialog
        title={dialog === 'create' ? 'New Shelf' : 'Rename'}
        onclose={() => (dialog = '')}
      >
        {#if dialog === 'renameItem'}<p>
            {current?.owned
              ? 'Renames Tooki’s copy. The original keeps its name.'
              : 'Renames the original file on disk.'}
          </p>{/if}
        <TextInput class="text-field" aria-label="Name" bind:value={name} />
        <div class="dialog-actions">
          <Button onclick={() => (dialog = '')}>Cancel</Button><Button
            disabled={busy}
            onclick={() => void perform(dialog, { name })}
            >{dialog === 'create' ? 'Create Shelf' : 'Save name'}</Button
          >
        </div>
      </Dialog>{/if}{/snippet}
</PanelLayout>

{#snippet preview()}<DetailLayout label="Shelf preview">
    {#if current && itemDetail?.image}<img
        class="shelf-image"
        src={itemDetail.image}
        alt={current.name}
      />{:else if current}<div class="document-preview">
        <FolderOpen size={25} />
        <pre>{itemDetail?.text ?? current.name}</pre>
      </div>
    {:else if row}<div class="document-preview">
        <FolderOpen size={25} />
        <pre>{`${row.title}\n${row.subtitle}`}</pre>
      </div>
    {:else}<EmptyState
        title="Shelf Manager"
        description="Collect files and text across independent shelves."
      />{/if}
    {#snippet information()}{#if current}<InformationList
          entries={[
            {
              label: 'Storage',
              value: current.owned ? 'Tooki copy' : 'Original reference',
            },
            { label: 'Path', value: current.path },
            { label: 'Available', value: itemDetail?.exists ? 'Yes' : 'No' },
            {
              label: 'Size',
              value:
                itemDetail?.bytes == null
                  ? '—'
                  : `${itemDetail.bytes.toLocaleString()} bytes`,
            },
          ]}
        />{/if}{/snippet}
  </DetailLayout>{/snippet}

<style>
  .shelf-image {
    display: block;
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
    margin: auto;
  }
</style>
