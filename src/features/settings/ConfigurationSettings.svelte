<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Button from '../../components/Button.svelte';
  type Category = {
    name: string;
    loadedAt: number | null;
    detail: string;
    error: string;
  };
  type Report = {
    folder: string;
    lastLoadedAt: number | null;
    legacySnippets: boolean;
    categories: Category[];
    warnings: string[];
  };
  const labels: Record<string, string> = {
    'settings.json': 'Settings',
    'shortcuts.json': 'Shortcuts',
    themes: 'Appearance',
    snippets: 'Snippets',
  };
  let report = $state<Report | null>(null);
  let busy = $state(false);
  let error = $state('');
  let completed = $state(false);
  const time = (value: number) => new Date(value * 1000).toLocaleString();
  async function refresh(reload = false) {
    if (!isTauri() || busy) return;
    busy = true;
    error = '';
    try {
      report = await invoke(
        reload ? 'reload_configuration' : 'configuration_status',
      );
      completed = reload;
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  async function openFolder() {
    try {
      await invoke('open_configuration_folder');
    } catch (reason) {
      error = String(reason);
    }
  }
  onMount(() => {
    void refresh();
  });
</script>

<SettingsSection
  title="Configuration"
  description="Loaded when Tooki starts. After syncing or editing files outside Tooki, reload them here. Changes made in Tooki apply immediately."
>
  <SettingsRow
    title="Configuration folder"
    description={report?.folder ?? '~/.config/tooki'}
  >
    <Button disabled={!report || busy} onclick={() => void openFolder()}
      >Open Folder</Button
    >
  </SettingsRow>
  <SettingsRow
    title="Load files from disk"
    description={report?.lastLoadedAt
      ? `Last successful load: ${time(report.lastLoadedAt)}`
      : 'No successful load recorded.'}
  >
    <Button disabled={!report || busy} onclick={() => void refresh(true)}
      >{busy ? 'Loading…' : 'Reload Configuration'}</Button
    >
  </SettingsRow>
  {#each report?.categories ?? [] as category}
    <SettingsRow
      title={labels[category.name] ?? category.name}
      description={`${category.name}${category.name.includes('.') ? '' : '/'} · ${category.detail || 'Not loaded'}`}
    >
      <span class:error={!!category.error}
        >{category.error ? 'Needs attention' : 'Loaded'}</span
      >
    </SettingsRow>
    {#if category.error}<p class="configuration-error" role="alert">
        {category.error}
      </p>{/if}
  {/each}
</SettingsSection>
{#if completed}<p class="settings-note" role="status">
    {report?.categories.some((category) => category.error)
      ? 'Some files could not be loaded. Their previous configuration was kept.'
      : 'Configuration reloaded.'}
  </p>{/if}
{#if report?.legacySnippets}<p class="settings-note">
    snippets.json is the old Swift library, imported once. Tooki now loads
    snippets from the snippets/ folder. Changes to the old file are not imported
    again.
  </p>{/if}
{#each report?.warnings ?? [] as warning}<p
    class="settings-message"
    role="alert"
  >
    {warning}
  </p>{/each}
{#if error}<p class="settings-message" role="alert">{error}</p>{/if}

<style>
  .error {
    color: var(--color-danger, #ee8c86);
  }
  .configuration-error {
    margin: 0;
    padding: 0 0 16px;
    color: var(--color-danger, #ee8c86);
    overflow-wrap: anywhere;
    font-size: 13px;
  }
</style>
