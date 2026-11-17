<script lang="ts">
  import { onMount, tick, untrack } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import {
    Copy,
    ClipboardPaste,
    Settings,
    TextCursorInput,
  } from '@lucide/svelte';
  import {
    request,
    row as snippetRow,
    type Record,
    type Library,
    type Pending,
    type Arguments,
    type Evaluation,
  } from './api';
  import { nextIndex } from '../../lib/navigation';
  import PanelLayout from '../../components/PanelLayout.svelte';
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ListDetailPanel from '../../components/ListDetailPanel.svelte';
  import GroupedPanelList from '../../components/GroupedPanelList.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import BottomActionBar from '../../components/BottomActionBar.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import Button from '../../components/Button.svelte';
  import SnippetPreview from './SnippetPreview.svelte';
  import './snippets.css';
  let {
    initialId = '',
    initialArguments = {},
    onback,
    onsettings,
  }: {
    initialId?: string;
    initialArguments?: Arguments;
    onback: () => void;
    onsettings: () => void;
  } = $props();
  let records = $state<Record[]>([]),
    pending = $state<Pending | null>(null);
  let query = $state(''),
    filter = $state('all'),
    selectedId = $state('');
  let values = $state<Arguments>({}),
    result = $state<Evaluation | null>(null);
  let previewError = $state(''),
    status = $state(''),
    preparing = $state(false),
    busy = $state(false),
    actions = $state(false),
    refresh = $state(0);
  let list = $state<HTMLDivElement>();
  let visible = $derived(
    records.filter(
      (record) =>
        record.configuration.enabled &&
        (filter === 'all' || record.definition.kind === filter) &&
        (!pending || record.definition.id === pending.id) &&
        `${record.definition.name} ${record.configuration.trigger} ${record.definition.collection}`
          .toLowerCase()
          .includes(query.toLowerCase()),
    ),
  );
  let selected = $derived(
    visible.findIndex((record) => record.definition.id === selectedId),
  );
  let record = $derived(visible[selected]);
  let disabled = $derived(
    !record || preparing || busy || result?.ticket == null || !!previewError,
  );
  function choose(next: Record | undefined, args: Arguments = {}) {
    if ((next?.definition.id ?? '') === selectedId && !Object.keys(args).length)
      return;
    selectedId = next?.definition.id ?? '';
    values = { ...next?.configuration.defaults, ...args };
    result = null;
    status = '';
    refresh++;
  }
  $effect(() => {
    const first = visible[0];
    if (!visible.some((record) => record.definition.id === selectedId))
      untrack(() => choose(first));
  });
  $effect(() => {
    selected;
    list
      ?.querySelector<HTMLElement>(`[data-index="${selected}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  });
  async function load() {
    records = (await request<Library>('list')).records;
  }
  async function back(close = false) {
    await request('cancel');
    if (pending || close) await invoke('dismiss_launcher');
    else onback();
  }
  async function run(action = pending ? 'expand' : 'copy') {
    if (disabled || !result) return;
    busy = true;
    status = '';
    actions = false;
    try {
      await request('run', { ticket: result.ticket, action });
    } catch (reason) {
      status = String(reason);
      refresh++;
    } finally {
      busy = false;
    }
  }
  function keyboard(event: KeyboardEvent) {
    if (
      event.defaultPrevented ||
      event.isComposing ||
      actions ||
      document.querySelector('dialog[open]')
    )
      return;
    const command = event.metaKey || event.ctrlKey;
    if (event.key === 'Escape') {
      event.preventDefault();
      void back(command).catch((reason) => (status = String(reason)));
    } else if (command && event.key === ',') {
      event.preventDefault();
      onsettings();
    } else if (command && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      actions = true;
    } else if (
      event.key === 'Enter' &&
      (command || (event.target as HTMLElement)?.tagName === 'INPUT')
    ) {
      event.preventDefault();
      void run(command && !pending ? 'paste' : undefined);
    } else if (
      ['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown'].includes(event.key) &&
      (event.target as HTMLElement)?.id === 'search'
    ) {
      event.preventDefault();
      choose(
        visible[
          nextIndex(
            event.key,
            Math.max(0, selected),
            visible.length,
            8,
            command,
          )
        ],
      );
    }
  }
  onMount(() => {
    let disposed = false;
    let stop: (() => void) | undefined;
    void (async () => {
      pending = await request<Pending | null>('begin');
      await load();
      if (disposed) return;
      const target = pending?.id || initialId;
      choose(
        records.find((record) => record.definition.id === target) ?? visible[0],
        pending?.arguments ?? initialArguments,
      );
      status = pending?.error ?? '';
      await tick();
      if (pending || initialId)
        document
          .querySelector<HTMLElement>(
            '.snippet-input input, .snippet-input button',
          )
          ?.focus();
      else document.getElementById('search')?.focus();
    })().catch((reason) => (status = String(reason)));
    void listen(
      'snippets-changed',
      () => void load().catch((reason) => (status = String(reason))),
    ).then((fn) => {
      if (disposed) fn();
      else stop = fn;
    });
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<svelte:window onkeydown={keyboard} />
<PanelLayout>
  {#snippet header()}<SearchHeader
      bind:query
      bind:filter
      clipboard={true}
      onback={() => void back().catch((reason) => (status = String(reason)))}
      placeholder={pending ? 'Complete your snippet…' : 'Search snippets…'}
      filterOptions={[
        { value: 'all', label: 'All Snippets' },
        { value: 'text', label: 'Text & Dates' },
        { value: 'choice', label: 'Choice Lists' },
        { value: 'template', label: 'Templates' },
      ]}
    />{/snippet}
  <ListDetailPanel>
    <GroupedPanelList
      items={visible.map(snippetRow)}
      group={(item) => item.group}
      label="Snippets"
      bind:element={list}
    >
      {#snippet row(item, index)}<ResultRow
          {item}
          {index}
          selected={index === selected}
          onclick={() => choose(visible[index])}
          onopen={() => {
            if (index === selected) void run();
            else choose(visible[index]);
          }}
        />{/snippet}
      {#snippet empty()}<EmptyState
          title={query ? 'No matching snippets' : 'Create your first snippet'}
          description="Manage text, choices, and templates in Settings."
        />
        <div class="snippet-starters">
          <Button onclick={onsettings}>Open Snippets Settings</Button>
        </div>{/snippet}
    </GroupedPanelList>
    {#snippet detail()}
      <div class="snippet-detail">
        {#if record}<h2>{record.definition.name}</h2>
          <span class="snippet-trigger">{record.configuration.trigger}</span
          >{#if record.definition.description}<p class="snippet-hint">
              {record.definition.description}
            </p>{/if}
          {#if pending}<p class="snippet-pending-note">
              Complete the inputs, then Expand. Escape cancels and leaves your
              original trigger unchanged.
            </p>{/if}
          <SnippetPreview
            {record}
            {refresh}
            saved={true}
            bind:values
            bind:result
            bind:error={previewError}
            bind:busy={preparing}
          />
        {:else}<EmptyState
            title="Ready when you are"
            description="Choose a snippet to preview its result."
          />{/if}
      </div>
    {/snippet}
  </ListDetailPanel>
  {#snippet footer()}<BottomActionBar
      clipboard={true}
      count={visible.length}
      selectedIndex={selected}
      status={status ||
        (pending ? 'Your trigger stays in place until you expand.' : '')}
      primaryLabel={pending ? 'Expand' : 'Copy'}
      {disabled}
      onprimary={() => void run()}
      onactions={() => (actions = !actions)}
      {onsettings}
      secondaryAction={{
        label: pending ? 'Copy Instead' : 'Paste',
        shortcut: pending ? '' : 'Super+Enter',
        disabled,
        run: () => void run(pending ? 'copy' : 'paste'),
      }}
    />{/snippet}
  {#snippet overlay()}{#if actions}<PopupSurface
        title="Snippet actions"
        onclose={() => (actions = false)}
        ><ActionsMenu
          actions={[
            ...(pending
              ? [
                  {
                    id: 'expand',
                    label: 'Expand in Original App',
                    icon: TextCursorInput,
                    run: () => void run('expand'),
                  },
                ]
              : []),
            {
              id: 'copy',
              label: 'Copy Result',
              icon: Copy,
              run: () => void run('copy'),
            },
            ...(!pending
              ? [
                  {
                    id: 'paste',
                    label: 'Paste into Previous App',
                    icon: ClipboardPaste,
                    run: () => void run('paste'),
                  },
                ]
              : []),
            {
              id: 'settings',
              label: 'Manage Snippets',
              icon: Settings,
              run: onsettings,
            },
          ]}
        /></PopupSurface
      >{/if}{/snippet}
</PanelLayout>
