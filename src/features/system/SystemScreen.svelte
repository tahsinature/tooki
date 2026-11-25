<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import registry from '../shortcuts/commands.json';
  import { commandSupport } from '../shortcuts/availability.svelte';
  import { commandAvailable } from '../shortcuts/availability';
  import type { Item } from '../../lib/data';
  import { nextIndex } from '../../lib/navigation';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ListDetailPanel from '../../components/ListDetailPanel.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import { Play, Settings, RefreshCw } from '@lucide/svelte';
  import { observeKeepAwake, statusText } from '../keep-awake/status.svelte';
  const awake = observeKeepAwake();
  let {
    initialTarget,
    tool = 'system',
    onback,
    onsettings,
  }: {
    initialTarget: string;
    tool?: 'system' | 'keepAwake';
    onback: () => void;
    onsettings: () => void;
  } = $props();
  let toolTitle = $derived(
    tool === 'keepAwake' ? 'Keep Awake' : 'System Actions',
  );
  type Volume = { id: string; name: string; path: string };
  let disks = $state(false);
  let volumes = $state<Volume[]>([]);
  let query = $state('');
  let filter = $state('all');
  let selected = $state(0);
  let busy = $state(false);
  let status = $state('');
  let actions = $state(false);
  let list = $state<HTMLDivElement>();
  const descriptions: Record<string, string> = {
    'command:system.sleep': 'Put your computer to sleep.',
    'command:system.emptyTrash':
      'Permanently delete items in Trash. Confirmation required.',
    'command:system.eject': 'Choose a mounted disk to safely eject.',
  };
  let rows = $derived(
    (disks
      ? volumes.map((volume): Item => ({
          id: volume.id,
          title: volume.name,
          subtitle: volume.path,
          kind: 'file',
          content: volume.path,
          group: 'Ejectable disks',
          source: '',
          time: '',
        }))
      : registry
          .filter(
            (command) =>
              command.tool === tool &&
              !command.root &&
              commandAvailable(command.id, commandSupport.values),
          )
          .map((command): Item => ({
            id: command.id,
            title: command.title,
            subtitle: command.id.startsWith('command:system.keepAwake')
              ? awake.state.error ||
                (awake.state.value
                  ? statusText(awake.state.value)
                  : 'Checking Keep Awake status…')
              : descriptions[command.id],
            kind: 'command',
            content: descriptions[command.id] ?? 'keep awake wake lock',
            group: toolTitle,
            source: '',
            time: '',
          }))
    ).filter((item) =>
      `${item.title} ${item.subtitle} ${item.content}`
        .toLowerCase()
        .includes(query.toLowerCase()),
    ),
  );
  let item = $derived(rows[selected]);
  $effect(() => {
    query;
    selected = 0;
  });
  let initialSelectionApplied = $state(false);
  $effect(() => {
    if (initialSelectionApplied) return;
    const index = rows.findIndex((row) => row.id === initialTarget);
    if (index >= 0) {
      selected = index;
      initialSelectionApplied = true;
    }
  });
  $effect(() => {
    if (selected >= rows.length) selected = Math.max(0, rows.length - 1);
  });
  $effect(() => {
    selected;
    list
      ?.querySelector<HTMLElement>(`[data-index="${selected}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  });
  async function refresh() {
    busy = true;
    status = '';
    try {
      volumes = await invoke<Volume[]>('system_volumes');
    } catch (error) {
      status = String(error);
    } finally {
      busy = false;
    }
  }
  async function showDisks() {
    disks = true;
    query = '';
    selected = 0;
    await refresh();
    await tick();
    document.getElementById('search')?.focus();
  }
  function back() {
    if (disks) {
      disks = false;
      query = '';
      status = '';
      selected = 0;
    } else onback();
  }
  async function run() {
    if (!item || busy) return;
    const target = item;
    actions = false;
    if (!disks && target.id === 'command:system.eject') {
      await showDisks();
      return;
    }
    busy = true;
    status = '';
    try {
      if (disks) {
        await invoke('eject_system_volume', { id: target.id });
        await refresh();
      } else {
        await invoke('execute_tool_command', { id: target.id });
        if (target.id.startsWith('command:system.keepAwake'))
          await awake.refresh();
      }
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
      document.querySelector('dialog[open]') ||
      actions
    )
      return;
    if ((event.metaKey || event.ctrlKey) && event.key === ',') {
      event.preventDefault();
      onsettings();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      back();
    } else if (
      (event.metaKey || event.ctrlKey) &&
      event.key.toLowerCase() === 'k'
    ) {
      event.preventDefault();
      actions = true;
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      selected = nextIndex(event.key, selected, rows.length, 10, false);
    } else if (
      event.key === 'Enter' &&
      (event.target as HTMLElement)?.tagName === 'INPUT'
    ) {
      event.preventDefault();
      void run();
    }
  }
  onMount(() => {
    if (initialTarget === 'command:system.eject') void showDisks();
    void tick().then(() => document.getElementById('search')?.focus());
  });
</script>

<svelte:window onkeydown={keyboard} />
<PanelLayout>
  {#snippet header()}<SearchHeader
      bind:query
      bind:filter
      clipboard={true}
      onback={back}
      placeholder={disks
        ? 'Search disks…'
        : `Search ${toolTitle.toLowerCase()}…`}
      filterOptions={[
        { value: 'all', label: disks ? 'All disks' : 'All actions' },
      ]}
    />{/snippet}
  <ListDetailPanel empty={rows.length === 0 ? panelEmpty : undefined}>
    <GroupedPanelList
      items={rows}
      group={(row) => row.group}
      label={disks ? 'Ejectable disks' : toolTitle}
      bind:element={list}
    >
      {#snippet row(row, index)}<ResultRow
          item={row}
          {index}
          selected={index === selected}
          onclick={() => (selected = index)}
          onactions={() => (actions = true)}
          onopen={() => {
            selected = index;
            void run();
          }}
        />{/snippet}
      {#snippet empty()}{@render panelEmpty()}{/snippet}
    </GroupedPanelList>
  </ListDetailPanel>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      count={rows.length}
      selectedIndex={selected}
      status={status ||
        (disks
          ? 'Ejecting a disk can also disconnect its other volumes.'
          : (item?.subtitle ?? ''))}
      primaryLabel={disks ? 'Eject' : 'Run'}
      disabled={busy || !item}
      onprimary={() => void run()}
      onactions={() => (actions = !actions)}
      {onsettings}
      secondaryAction={disks
        ? { label: 'Refresh', disabled: busy, run: () => void refresh() }
        : undefined}
    />{/snippet}
  {#snippet overlay()}{#if actions}<PopupSurface
        title={toolTitle}
        onclose={() => (actions = false)}
      >
        <ActionsMenu
          actions={[
            ...(item
              ? [
                  {
                    id: 'run',
                    label: disks ? `Eject ${item.title}` : item.title,
                    icon: Play,
                    run: () => void run(),
                  },
                ]
              : []),
            ...(disks
              ? [
                  {
                    id: 'refresh',
                    label: 'Refresh disks',
                    icon: RefreshCw,
                    run: () => {
                      actions = false;
                      void refresh();
                    },
                  },
                ]
              : []),
            {
              id: 'settings',
              label: `${toolTitle} settings`,
              icon: Settings,
              run: onsettings,
            },
            ...(status.includes('Automation')
              ? [
                  {
                    id: 'permissions',
                    label: 'Open Automation settings',
                    icon: Settings,
                    run: () => {
                      void invoke('open_automation_settings').catch(
                        (error) => (status = String(error)),
                      );
                    },
                  },
                ]
              : []),
          ]}
        />
      </PopupSurface>{/if}{/snippet}
</PanelLayout>

{#snippet panelEmpty()}<EmptyState
    title={busy
      ? 'Loading…'
      : disks
        ? 'No ejectable disks'
        : 'No matching actions'}
    description={disks
      ? 'Connect an ejectable disk, then choose Refresh.'
      : 'Try another search or check platform support in Settings.'}
  />{/snippet}
