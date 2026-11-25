<script lang="ts">
  import ActivityLog from './components/activity-log/ActivityLog.svelte';
  import { logEntries, logColumns, logFilters } from './features/detective/log';
  const sampleChecks = Array.from({ length: 5000 }, (_, index) => ({
    id: index + 1,
    timestamp: Date.UTC(2026, 10, 16, 9, 0, index),
    combo: { key: index % 2 ? 'f' : 'space', modifiers: 8 },
    outcome: index % 3 ? 'delivered' : 'lookup',
    detail: `Synthetic gallery check ${index + 1}. No real keyboard monitoring is used here.`,
    app: 'Example App',
    matches: index % 3 ? [{ owner: 'Example App', detail: 'Edit › Find' }] : [],
  }));
  let activity = $state(logEntries(sampleChecks, 'macOS'));
  import SearchHeader from './components/SearchHeader.svelte';
  import ResultRow from './components/ResultRow.svelte';
  import GroupedPanelList from './components/GroupedPanelList.svelte';
  import PanelLayout from './components/PanelLayout.svelte';
  import ListDetailPanel from './components/ListDetailPanel.svelte';
  import DetailPanel from './components/DetailPanel.svelte';
  import BottomActionBar from './components/BottomActionBar.svelte';
  import ActionsPopup from './components/ActionsPopup.svelte';
  import EmptyState from './components/EmptyState.svelte';
  import { clipboardEmptyState } from './features/clipboard/emptyState';
  import DropOverlay from './components/DropOverlay.svelte';
  import Keycap from './components/Keycap.svelte';
  import SettingsSection from './components/settings/SettingsSection.svelte';
  import SettingsRow from './components/settings/SettingsRow.svelte';
  import Toggle from './components/Toggle.svelte';
  import Button from './components/Button.svelte';
  import ConfirmationActions from './components/ConfirmationActions.svelte';
  import Dialog from './components/Dialog.svelte';
  import { allThemes, selectTheme } from './lib/themes/store.svelte';
  let checked = $state(true);
  let dialog = $state(false);
  let confirmation = $state(false);
  import { samples } from './lib/data';
  let query = $state('');
  let filter = $state('all');
  let selected = $state('welcome');
  let actions = $state(false);
  let pinned = $state(true);
  let status = $state('');
  let drop = $state<'hidden' | 'hover' | 'saving'>('hidden');
  let emptyPreview = $state(false);
  let items = $derived(
    (emptyPreview ? [] : samples)
      .slice(0, 6)
      .map((item, index) => ({
        ...item,
        ...(item.id === 'welcome' ? { pinned } : {}),
        dropped: index === 1,
        unavailable: index === 2,
      }))
      .filter(
        (item) =>
          item.title.toLowerCase().includes(query.toLowerCase()) &&
          (filter === 'all' ||
            (filter === 'pinned'
              ? item.pinned
              : filter === 'dropped'
                ? item.dropped
                : filter === 'unavailable'
                  ? item.unavailable
                  : item.kind === filter)),
      )
      .sort((a, b) => Number(!!b.pinned) - Number(!!a.pinned)),
  );
  let item = $derived(items.find((item) => item.id === selected) ?? items[0]);
</script>

<div class="component-gallery">
  <header class="gallery-heading">
    <div>
      <h1>Shared components</h1>
      <p>Subtle corners · Compact spacing · Shared across tools</p>
    </div>
    <div class="gallery-theme-picker">
      {#each allThemes() as theme}<Button onclick={() => selectTheme(theme.id)}
          >{theme.name}</Button
        >{/each}<a href="/">Back to prototype</a>
    </div>
  </header>
  <div class="gallery-theme-picker">
    <Button onclick={() => (emptyPreview = !emptyPreview)}
      >{emptyPreview ? 'Show sample items' : 'Empty state'}</Button
    >
    <Button onclick={() => (drop = drop === 'hover' ? 'hidden' : 'hover')}
      >Drop overlay</Button
    >
    <Button onclick={() => (drop = drop === 'saving' ? 'hidden' : 'saving')}
      >Saving overlay</Button
    >
    {#if drop !== 'hidden'}<Button onclick={() => (drop = 'hidden')}
        >Hide overlay</Button
      >{/if}
  </div>
  <section aria-label="Composed list-detail panel" class="gallery-panel">
    <PanelLayout>
      {#snippet header()}<SearchHeader
          bind:query
          bind:filter
          clipboard={true}
          onback={() => {
            query = '';
            filter = 'all';
          }}
        />{/snippet}
      <ListDetailPanel empty={items.length === 0 ? panelEmpty : undefined}>
        <GroupedPanelList
          {items}
          label="Sample clips"
          group={(item) => (item.pinned ? 'Pinned' : item.group)}
        >
          {#snippet row(row, index)}<ResultRow
              item={row}
              {index}
              selected={item?.id === row.id}
              onclick={() => (selected = row.id)}
              onactions={() => (actions = true)}
              onopen={() => (status = 'Preview action triggered')}
            />{/snippet}
          {#snippet empty()}{@render panelEmpty()}{/snippet}
        </GroupedPanelList>
        {#snippet detail()}{#if item}<DetailPanel {item} />{:else}<aside
              class="detail"
            >
              <EmptyState />
            </aside>{/if}{/snippet}
      </ListDetailPanel>
      {#snippet footer()}<BottomActionBar
          clipboard={true}
          count={items.length}
          selectedIndex={items.findIndex((entry) => entry.id === selected)}
          {status}
          disabled={!item}
          onprimary={() => (status = 'Preview action triggered')}
          onactions={() => (actions = !actions)}
        />{/snippet}
      {#snippet overlay()}{#if drop !== 'hidden'}<DropOverlay
            saving={drop === 'saving'}
          />{/if}{#if actions && item}<ActionsPopup
            clipboard={true}
            pinned={!!item.pinned}
            onclose={() => (actions = false)}
            oncopy={() => {
              status = 'Preview action triggered';
              actions = false;
            }}
            onpin={() => {
              pinned = !pinned;
              actions = false;
            }}
          />{/if}{/snippet}
    </PanelLayout>
  </section>
  <section
    id="activity-log"
    aria-label="Activity log example"
    style="height: 420px; display: flex; flex-direction: column; gap: 8px"
  >
    <ActivityLog
      entries={activity}
      columns={logColumns}
      filters={logFilters}
      title="Activity Log · 5,000 synthetic checks"
      onclear={() => {
        activity = [];
      }}
    />
    <Button
      onclick={() => {
        const id = (activity.at(-1)?.id ? Number(activity.at(-1)!.id) : 0) + 1;
        activity = [
          ...activity,
          ...logEntries(
            [{ ...sampleChecks[0], id, timestamp: Date.now() }],
            'macOS',
          ),
        ];
      }}>Append sample result</Button
    >
  </section>
  <section class="gallery-reference" aria-label="Component reference">
    <div>
      <h2>Panel structure</h2>
      <p>PanelLayout · ListDetailPanel · GroupedPanelList · SectionHeader</p>
    </div>
    <div>
      <h2>Controls and feedback</h2>
      <p>SearchHeader · PanelFilterMenu · ResultRow · BottomActionBar</p>
    </div>
    <div>
      <h2>Popups and details</h2>
      <p>PopupSurface · ActionsPopup · DetailPanel · InformationList</p>
    </div>
    <div>
      <h2>Keycap</h2>
      <Keycap text="⌘" />
      <Keycap text="K" />
      <Keycap text="↵" />
    </div>
  </section>
  <SettingsSection title="Settings controls">
    <SettingsRow
      title="Toggle"
      description="Shared switch with keyboard and screen-reader support."
      ><Toggle
        label="Example preference"
        {checked}
        onchange={(value) => (checked = value)}
      /></SettingsRow
    >
    <SettingsRow title="Buttons and dialogs"
      ><Button onclick={() => (dialog = true)}>Open dialog</Button><Button
        onclick={() => (confirmation = true)}>Open confirmation</Button
      ><Button disabled>Disabled</Button></SettingsRow
    >
  </SettingsSection>
  {#if confirmation}<ConfirmationActions
      title="Empty Trash?"
      description="Permanently delete all items in the Trash? This cannot be undone."
      confirmLabel="Empty Trash"
      onclose={() => (confirmation = false)}
      onconfirm={() => {
        confirmation = false;
      }}
    />{/if}
  {#if dialog}<Dialog title="Shared dialog" onclose={() => (dialog = false)}
      ><p>Uses the current theme and native modal focus management.</p>
      <Button onclick={() => (dialog = false)}>Done</Button></Dialog
    >{/if}
  <section class="gallery-empty" aria-label="EmptyState example">
    <EmptyState />
  </section>
</div>

{#snippet panelEmpty()}<EmptyState
    {...clipboardEmptyState(query, filter)}
  />{/snippet}

<style>
  .component-gallery {
    max-width: 1100px;
    margin: auto;
    padding: 28px;
  }
  .gallery-theme-picker {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
  }
  .gallery-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
    margin-bottom: 24px;
  }
  h1 {
    font-size: 22px;
    margin: 0 0 8px;
  }
  h2 {
    font-size: 13px;
    margin: 0 0 8px;
  }
  p {
    color: var(--muted);
    font-size: 12px;
    margin: 0;
    line-height: 1.6;
  }
  a {
    color: var(--ink);
    font-size: 12px;
    text-decoration: underline;
  }
  .gallery-panel {
    height: 550px;
  }
  .gallery-panel :global(.app-shell) {
    height: 100%;
  }
  .gallery-reference {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 24px;
    padding: 24px 0;
  }
  .gallery-empty {
    border: 1px solid var(--line);
    border-radius: var(--shell-radius);
  }
</style>
