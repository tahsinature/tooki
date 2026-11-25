<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import {
    Activity,
    Pause,
    Play,
    Settings,
    ExternalLink,
    RefreshCw,
  } from '@lucide/svelte';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ListDetailPanel from '../../components/ListDetailPanel.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import MonitorDetail from './MonitorDetail.svelte';
  import { nextIndex } from '../../lib/navigation';
  import {
    appendSample,
    bytes,
    memoryBytes,
    percent,
    speed,
    views,
    type View,
    type Snapshot,
    type Sample,
  } from './model';
  import type { Item } from '../../lib/data';
  import './monitor.css';
  let { onback, onsettings }: { onback: () => void; onsettings: () => void } =
    $props();
  let query = $state(''),
    filter = $state('all'),
    view = $state<View>('overview');
  let data = $state<Snapshot | null>(null),
    history = $state<Sample[]>([]);
  let error = $state(''),
    paused = $state(false),
    actions = $state(false),
    loading = $state(true);
  let list = $state<HTMLDivElement>();
  let session = crypto.randomUUID();
  let busy = false;
  let disposed = false;
  let timer: ReturnType<typeof setTimeout>;
  const labels: Record<View, string> = {
    overview: '',
    cpu: 'CPU',
    memory: 'Memory',
    storage: 'Storage',
    power: 'Power',
    network: 'Network',
  };
  let network = $derived(
    data?.interfaces.find((i) => i.primary) ?? data?.interfaces[0],
  );
  let rows = $derived(
    views
      .filter((v) =>
        `${v.title} ${v.keywords}`.toLowerCase().includes(query.toLowerCase()),
      )
      .map((v): Item => ({
        id: `monitor:${v.id}`,
        title: v.title,
        subtitle: v.keywords,
        content: '',
        group: labels[v.id],
        kind: 'command',
        source: '',
        time: '',
        metadata: !data
          ? '—'
          : v.id === 'cpu'
            ? percent(data.cpu.total)
            : v.id === 'memory'
              ? memoryBytes(data.memory?.used)
              : v.id === 'storage'
                ? `${bytes(data.storage.available)} free`
                : v.id === 'power'
                  ? data.battery.percent == null
                    ? '—'
                    : percent(data.battery.percent)
                  : v.id === 'network'
                    ? network
                      ? speed(network.download)
                      : 'Offline'
                    : '',
      })),
  );
  let selected = $derived(
    rows.findIndex((row) => row.id === `monitor:${view}`),
  );
  $effect(() => {
    if (selected < 0 && rows[0]) view = rows[0].id.slice(8) as View;
  });
  $effect(() => {
    view;
    void tick().then(() =>
      list
        ?.querySelector('[aria-current="true"]')
        ?.scrollIntoView({ block: 'nearest' }),
    );
  });
  async function refresh() {
    if (busy || paused || disposed) return;
    busy = true;
    const requestSession = session;
    try {
      if (!isTauri())
        throw new Error(
          'Open System Monitor in the Tooki desktop app to see live readings.',
        );
      const snapshot = await invoke<Snapshot | null>(
        'system_monitor_snapshot',
        { session: requestSession },
      );
      if (disposed || paused || session !== requestSession) return;
      if (snapshot) {
        data = snapshot;
        history = appendSample(history, snapshot);
        error = '';
      } else {
        session = crypto.randomUUID();
        history = [];
      }
    } catch (reason) {
      if (!disposed) error = String(reason);
    } finally {
      busy = false;
      if (!disposed) loading = false;
    }
  }
  function togglePaused() {
    paused = !paused;
    actions = false;
    document.getElementById('search')?.focus();
    if (!paused) {
      session = crypto.randomUUID();
      history = [];
      void refresh();
    }
  }
  async function openActivity() {
    actions = false;
    try {
      await invoke('open_activity_monitor');
    } catch (reason) {
      error = String(reason);
    }
  }
  onMount(() => {
    document.getElementById('search')?.focus();
    async function poll() {
      await refresh();
      if (!disposed) timer = setTimeout(poll, 2000);
    }
    void poll();
    return () => {
      disposed = true;
      clearTimeout(timer);
    };
  });
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
      if (actions) actions = false;
      else if (query) query = '';
      else onback();
      document.getElementById('search')?.focus();
    } else if (command && event.key === ',') {
      event.preventDefault();
      onsettings();
    } else if (command && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      actions = !actions;
    } else if (
      !actions &&
      (event.target as HTMLElement)?.closest('.result-list, .search-header') &&
      ['ArrowDown', 'ArrowUp', 'Home', 'End', 'PageDown', 'PageUp'].includes(
        event.key,
      )
    ) {
      event.preventDefault();
      const row =
        rows[
          nextIndex(event.key, Math.max(0, selected), rows.length, 5, command)
        ];
      if (row) view = row.id.slice(8) as View;
    } else if (
      !actions &&
      event.key === 'Enter' &&
      (event.target as HTMLElement)?.id === 'search'
    ) {
      event.preventDefault();
      void openActivity();
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
      placeholder="Search system monitor…"
      filterOptions={[]}
    />{/snippet}
  <ListDetailPanel empty={rows.length === 0 ? panelEmpty : undefined}>
    <GroupedPanelList
      items={rows}
      group={(row) => row.group}
      label="System Monitor views"
      bind:element={list}
    >
      {#snippet row(row, index)}<ResultRow
          item={row}
          {index}
          selected={index === selected}
          onclick={() => (view = row.id.slice(8) as View)}
          onactions={() => (actions = true)}
          onopen={() => (view = row.id.slice(8) as View)}
        />{/snippet}
      {#snippet empty()}{@render panelEmpty()}{/snippet}
    </GroupedPanelList>
    {#snippet detail()}
      <!-- The scrollable details region must be reachable by keyboard. -->
      <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
      <div
        role="region"
        class="detail monitor-detail"
        aria-label={`${views.find((v) => v.id === view)?.title} details`}
        tabindex="0"
      >
        {#if error}<p class="monitor-error" role="alert">{error}</p>{/if}
        {#if data}<MonitorDetail
            {data}
            {history}
            {view}
            onview={(next) => (view = next)}
          />
        {:else if !error}<EmptyState
            title={loading ? 'Reading your Mac…' : 'Waiting for readings'}
            description="Live readings appear while this tool is visible."
          />{/if}
      </div>{/snippet}
  </ListDetailPanel>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      toolIcon={Activity}
      count={rows.length}
      selectedIndex={selected}
      status={error ? 'Readings unavailable' : paused ? 'Paused' : 'Live · 2s'}
      primaryLabel="Activity Monitor"
      onprimary={() => void openActivity()}
      onactions={() => (actions = !actions)}
      disabled={false}
      {onsettings}
    />{/snippet}
  {#snippet overlay()}{#if actions}<PopupSurface
        title="System Monitor actions"
        onclose={() => (actions = false)}
        ><ActionsMenu
          actions={[
            {
              id: 'activity',
              label: 'Open Activity Monitor',
              icon: ExternalLink,
              run: () => void openActivity(),
            },
            {
              id: 'pause',
              label: paused ? 'Resume readings' : 'Pause readings',
              icon: paused ? Play : Pause,
              run: togglePaused,
            },
            {
              id: 'refresh',
              label: 'Refresh readings',
              icon: RefreshCw,
              run: () => {
                actions = false;
                document.getElementById('search')?.focus();
                paused = false;
                void refresh();
              },
            },
            {
              id: 'settings',
              label: 'System Monitor settings',
              icon: Settings,
              run: onsettings,
            },
          ]}
        /></PopupSurface
      >{/if}{/snippet}
</PanelLayout>

{#snippet panelEmpty()}<EmptyState
    title="No matching views"
    description="Try CPU, memory, disk, battery, or network."
  />{/snippet}
