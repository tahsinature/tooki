<script lang="ts">
  import AssignmentIcon from './AssignmentIcon.svelte';
  import registry from './commands.json';
  import { assignment, launcherRow } from './assignments.svelte';
  import { appPreferences } from '../launcher/app-preferences.svelte';
  import { applicationCatalog } from '../launcher/application-catalog.svelte';
  import AssignmentRow from './AssignmentRow.svelte';
  import AssignmentGroup from '../../components/settings/AssignmentGroup.svelte';
  import SearchField from '../../components/SearchField.svelte';
  import PanelFilterMenu from '../../components/PanelFilterMenu.svelte';
  import Keycap from '../../components/Keycap.svelte';
  let query = $state('');
  let searchInput = $state<HTMLInputElement>();
  let filter = $state('customized');
  const groups: Record<string, string> = {
    notes: 'Notes',
    snippets: 'Snippets',
    emoji: 'Emoji',
    keepAwake: 'Keep Awake',
    clipboard: 'Clipboard',
    system: 'System Actions',
    systemMonitor: 'System Monitor',
  };
  let rows = $derived([
    launcherRow(),
    ...registry.map((command) =>
      assignment(command.id, command.title, groups[command.tool]),
    ),
    ...Object.keys(appPreferences.values)
      .filter(
        (id) =>
          !id.startsWith('command:') && appPreferences.values[id].shortcut,
      )
      .map((id) =>
        assignment(
          id,
          applicationCatalog.items.find((item) => item.id === `app:${id}`)
            ?.title ??
            id
              .split('/')
              .pop()
              ?.replace(/\.app$/, '') ??
            id,
          'Applications',
        ),
      ),
  ]);
  let visible = $derived(
    rows.filter(
      (item) =>
        (filter !== 'customized' || item.customized) &&
        `${item.title} ${item.group} ${item.shortcut}`
          .toLowerCase()
          .includes(query.toLowerCase()),
    ),
  );
</script>

<div class="shortcuts-page settings-fill-page">
  <div class="shortcut-filters">
    <SearchField
      bind:value={query}
      bind:element={searchInput}
      placeholder="Search shortcuts…"
      label="Search shortcuts"
    />
    <PanelFilterMenu
      bind:value={filter}
      onapply={() => searchInput?.focus({ preventScroll: true })}
      label="Shortcut assignments"
      options={[
        { value: 'customized', label: 'Customized' },
        { value: 'all', label: 'All shortcuts' },
      ]}
    />
  </div>
  <div class="shortcut-table">
    <div class="shortcut-columns">
      <span>Command</span><span>Shortcut</span>
    </div>
    <div class="shortcut-list">
      {#each ['General', 'Notes', 'Snippets', 'Clipboard', 'Emoji', 'Keep Awake', 'System Actions', 'System Monitor', 'Applications'] as group}
        {#if visible.some((item) => item.group === group)}
          <AssignmentGroup title={group}>
            {#each visible.filter((item) => item.group === group) as item (item.id)}<AssignmentRow
                {item}
              />{/each}
          </AssignmentGroup>
        {/if}
      {/each}
      {#if !visible.length}<p class="settings-note">
          No matching assignments. Choose All shortcuts to see available
          commands.
        </p>{/if}
      {#if filter === 'all' && (!query || 'open tooki settings built-in'.includes(query.toLowerCase()))}
        <AssignmentGroup title="Built-in">
          <div class="assignment-row">
            <div class="assignment-label">
              <AssignmentIcon group="Built-in" />
              <div class="assignment-name">Tooki Settings</div>
            </div>
            <span
              class="assignment-shortcut"
              aria-label="Open Tooki Settings shortcut"
            >
              <Keycap
                text={/Mac/.test(navigator.platform) ? '⌘' : 'Ctrl'}
              /><Keycap text="," />
            </span>
          </div>
        </AssignmentGroup>
      {/if}
    </div>
  </div>
</div>

<style>
  .shortcuts-page {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .shortcut-table {
    min-height: 0;
    overflow: hidden;
    border: 1px solid var(--line);
    border-radius: 10px;
    background: var(--panel);
    display: flex;
    flex-direction: column;
  }
  .shortcut-columns {
    display: flex;
    justify-content: space-between;
    padding: 10px 18px;
    font-size: 11px;
    color: var(--muted);
    border-bottom: 1px solid var(--line);
  }
  .shortcut-list {
    overflow: auto;
    min-height: 0;
  }
  .shortcut-list :global(.settings-note) {
    padding: 16px;
    margin: 0;
  }
  .shortcut-filters {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-shrink: 0;
  }
  .shortcut-filters :global(.search-field) {
    flex: 1;
    min-width: 0;
  }
</style>
