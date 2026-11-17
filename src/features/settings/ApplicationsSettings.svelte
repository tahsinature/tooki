<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import SearchField from '../../components/SearchField.svelte';
  import Button from '../../components/Button.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import ApplicationActions from '../launcher/ApplicationActions.svelte';
  import {
    applicationCatalog,
    refreshApplications,
  } from '../launcher/application-catalog.svelte';
  import { appPreferences } from '../launcher/app-preferences.svelte';
  import type { Item } from '../../lib/data';
  let search = $state('');
  let selected = $state<Item | null>(null);
  let message = $state('');
  let matches = $derived(
    applicationCatalog.items.filter((item) =>
      `${item.title} ${appPreferences.values[item.id.slice(4)]?.alias ?? ''}`
        .toLowerCase()
        .includes(search.toLowerCase()),
    ),
  );
  function description(item: Item) {
    const value = appPreferences.values[item.id.slice(4)];
    return [
      value?.favorite ? 'Favorite' : '',
      value?.alias ? `Alias: ${value.alias}` : '',
      value?.shortcut ? `Shortcut: ${value.shortcut}` : '',
      value?.shortcut_error ?? '',
    ]
      .filter(Boolean)
      .join(' · ');
  }
  async function open(item: Item) {
    try {
      await invoke('launch_application', { id: item.id.slice(4) });
      selected = null;
    } catch (reason) {
      message = String(reason);
    }
  }
</script>

<SettingsSection title="Application catalog">
  <SettingsRow
    title={applicationCatalog.refreshing
      ? 'Refreshing applications…'
      : `${applicationCatalog.items.length} applications`}
    description="Manage favorites, search aliases and launch shortcuts. Changes also appear in Root Search."
  >
    <Button
      disabled={applicationCatalog.refreshing}
      onclick={() => void refreshApplications()}>Refresh</Button
    >
  </SettingsRow>
</SettingsSection>
<div class="applications-search">
  <SearchField
    label="Search applications"
    placeholder="Search applications or aliases…"
    bind:value={search}
  />
</div>
{#if applicationCatalog.error || message}<p
    class="settings-message"
    role="status"
  >
    {applicationCatalog.error || message}
  </p>{/if}
{#if matches.length}
  <SettingsSection title="Installed applications">
    {#each matches as item (item.id)}
      <SettingsRow title={item.title} description={description(item)}>
        <Button
          label={`Actions for ${item.title}`}
          onclick={() => (selected = item)}>Actions…</Button
        >
      </SettingsRow>
    {/each}
  </SettingsSection>
{:else if !applicationCatalog.refreshing}
  <EmptyState
    title="No matching applications"
    description="Try another search or refresh the catalog."
  />
{/if}
{#if selected}
  {#key selected.id}
    <ApplicationActions
      item={selected}
      onopen={() => selected && void open(selected)}
      onclose={() => (selected = null)}
      onstatus={(value) => (message = value)}
    />
  {/key}
{/if}

<style>
  .applications-search {
    margin-bottom: 18px;
  }
</style>
