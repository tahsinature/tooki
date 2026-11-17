<script lang="ts">
  import registry from './commands.json';
  import { assignment, launcherRow } from './assignments.svelte';
  import { appPreferences } from '../launcher/app-preferences.svelte';
  import { applicationCatalog } from '../launcher/application-catalog.svelte';
  import AssignmentRow from './AssignmentRow.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import SearchField from '../../components/SearchField.svelte';
  import PanelFilterMenu from '../../components/PanelFilterMenu.svelte';
  import Keycap from '../../components/Keycap.svelte';
  let query = $state('');
  let filter = $state('customized');
  const groups: Record<string, string> = {
    notes: 'Notes',
    shelf: 'Shelf',
    clipboard: 'Clipboard',
    system: 'System Actions',
  };
  let rows = $derived([
    launcherRow(),
    ...registry.map((command) =>
      assignment(command.id, command.title, groups[command.tool]),
    ),
    ...Object.keys(appPreferences.values)
      .filter(
        (id) =>
          !id.startsWith('command:') &&
          (appPreferences.values[id].shortcut ||
            appPreferences.values[id].alias),
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
        `${item.title} ${item.group} ${item.alias} ${item.shortcut}`
          .toLowerCase()
          .includes(query.toLowerCase()),
    ),
  );
</script>

<div class="shortcut-filters">
  <SearchField
    bind:value={query}
    placeholder="Search shortcuts…"
    label="Search shortcuts"
  />
  <PanelFilterMenu
    bind:value={filter}
    label="Shortcut assignments"
    options={[
      { value: 'customized', label: 'Customized' },
      { value: 'all', label: 'All shortcuts' },
    ]}
  />
</div>
<p class="settings-note">
  {filter === 'customized'
    ? 'New assignments and changed defaults, including aliases.'
    : 'Tool commands, the launcher, and saved application assignments.'} Edit here
  or in the tool’s settings.
</p>
{#each ['General', 'Notes', 'Shelf', 'Clipboard', 'System Actions', 'Applications'] as group}
  {#if visible.some((item) => item.group === group)}
    <SettingsSection title={group}>
      {#each visible.filter((item) => item.group === group) as item (item.id)}<AssignmentRow
          {item}
        />{/each}
    </SettingsSection>
  {/if}
{/each}
{#if !visible.length}<p class="settings-note">
    No matching assignments. Choose All shortcuts to see available commands.
  </p>{/if}
{#if filter === 'all' && (!query || 'open settings built-in'.includes(query.toLowerCase()))}
  <SettingsSection title="Built-in"
    ><SettingsRow
      title="Open Settings"
      description="Fixed shortcut while a Tooki window is focused."
      ><Keycap text={/Mac/.test(navigator.platform) ? '⌘' : 'Ctrl'} /><Keycap
        text=","
      /></SettingsRow
    ></SettingsSection
  >
{/if}

<style>
  .shortcut-filters {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
  }
  .shortcut-filters :global(.search-field) {
    flex: 1;
    min-width: 0;
  }
</style>
