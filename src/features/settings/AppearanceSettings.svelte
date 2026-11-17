<script lang="ts">
  import { ArrowUpDown } from '@lucide/svelte';
  import { isTauri } from '@tauri-apps/api/core';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import SettingsMenuButton from '../../components/settings/SettingsMenuButton.svelte';
  import Button from '../../components/Button.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import { preferences, setPreference } from '../../lib/preferences.svelte';
  import ThemeCard from './ThemeCard.svelte';
  import ThemeEditor from './ThemeEditor.svelte';
  let editingTheme = $state(false);
  import {
    themeState,
    allThemes,
    activeTheme,
    selectTheme,
    importTheme,
    removeTheme,
  } from '../../lib/themes/store.svelte';
  let editor = $state(false);
  let source = $state('');
  let exporting = $state(false);
  let error = $state('');
  let message = $state('');
  let fileInput: HTMLInputElement;
  let selected = $derived(
    allThemes().find((theme) => theme.id === themeState.selected),
  );
  function openImport() {
    exporting = false;
    source = '';
    error = '';
    editor = true;
  }
  async function importPasted() {
    try {
      await importTheme(source);
      editor = false;
      message = 'Theme imported and applied.';
    } catch (cause) {
      error =
        cause instanceof Error ? cause.message : 'Could not import theme.';
    }
  }
  async function readFile(event: Event) {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;
    error = '';
    try {
      if (file.size > 32_000)
        throw new Error('Theme must be smaller than 32 KB.');
      source = await file.text();
      exporting = false;
      editor = true;
    } catch (cause) {
      message = cause instanceof Error ? cause.message : 'Could not read file.';
    }
    fileInput.value = '';
  }
  async function copyTheme() {
    const text = JSON.stringify(activeTheme(), null, 2);
    try {
      if (isTauri()) await writeText(text);
      else await navigator.clipboard.writeText(text);
      message = 'Theme JSON copied. Change its id and name to make your own.';
    } catch {
      message = 'Could not copy. Use Export JSON instead.';
    }
  }
  function exportTheme() {
    source = JSON.stringify(activeTheme(), null, 2);
    exporting = true;
    error = '';
    editor = true;
  }
</script>

<SettingsSection title="Window">
  <SettingsRow
    title="Window mode"
    description="Choose how much of the launcher is visible before you type."
  >
    <div class="mode-picker" role="group" aria-label="Window mode">
      <button
        class:chosen={!preferences.compactLauncher}
        aria-pressed={!preferences.compactLauncher}
        onclick={() => setPreference('compactLauncher', false)}
        ><span class="mode-preview"><i></i><i></i><i></i></span>Default</button
      >
      <button
        class:chosen={preferences.compactLauncher}
        aria-pressed={preferences.compactLauncher}
        onclick={() => setPreference('compactLauncher', true)}
        ><span class="mode-preview compact-preview"><i></i></span
        >Compact</button
      >
    </div>
  </SettingsRow>
</SettingsSection>
<p class="settings-note">
  In Compact mode, type to search or press ↓ to show all commands. Escape
  returns to the compact bar.
</p>
<p class="settings-message" role="status">{preferences.error}</p>

<SettingsSection title="Theme">
  <div class="theme-grid">
    {#each allThemes() as theme (theme.id)}
      <ThemeCard
        {theme}
        selected={themeState.selected === theme.id}
        onclick={() => selectTheme(theme.id)}
      />
    {/each}
  </div>
  <SettingsRow
    title="Customize theme"
    description="Adjust colors, corners, text size and spacing with a live preview."
  >
    <Button onclick={() => (editingTheme = true)}>Edit theme…</Button>
  </SettingsRow>
  {#if selected && themeState.custom.some((theme) => theme.id === selected.id)}
    <SettingsRow
      title={selected.name}
      description="Custom theme, saved on this device."
      ><Button
        destructive
        onclick={() => {
          if (selected) removeTheme(selected.id);
        }}>Remove theme</Button
      ></SettingsRow
    >
  {/if}
  <SettingsRow
    title="Import and share"
    description="Bring in a theme or share your current style."
  >
    <SettingsMenuButton
      label="Import / Share…"
      icon={ArrowUpDown}
      actions={[
        { label: 'Import from file…', run: () => fileInput.click() },
        { label: 'Import from JSON…', run: openImport },
        { label: 'Copy theme JSON', run: () => void copyTheme() },
        { label: 'Export theme JSON…', run: exportTheme },
      ]}
    />
  </SettingsRow>
</SettingsSection>
<input
  class="visually-hidden"
  tabindex="-1"
  aria-label="Import theme file"
  type="file"
  accept=".json,application/json"
  bind:this={fileInput}
  onchange={readFile}
/>
<p class="settings-message" role="status">
  {themeState.storageError || message}
</p>
{#if editor}
  <Dialog
    title={exporting ? 'Export theme' : 'Import theme'}
    onclose={() => (editor = false)}
  >
    <p class="settings-note">
      {exporting
        ? 'Copy this JSON into a .json file to share it or use it as the starting point for a new theme.'
        : 'Paste theme JSON below. Give your theme a unique id and name. It will apply after validation.'}
    </p>
    <label class="field-label" for="theme-source">Theme JSON</label>
    <textarea
      id="theme-source"
      class="text-field theme-source"
      bind:value={source}
      readonly={exporting}
      spellcheck="false"
      placeholder={'{ "version": 1, "id": "my-theme", … }'}></textarea>
    {#if error}<p class="error-message" role="alert">{error}</p>{/if}
    {#if exporting}<p class="settings-message" role="status">{message}</p>{/if}
    <div class="dialog-actions">
      <Button onclick={() => (editor = false)}>Cancel</Button
      >{#if exporting}<Button onclick={() => void copyTheme()}>Copy JSON</Button
        >{:else}<Button disabled={!source.trim()} onclick={importPasted}
          >Import and apply</Button
        >{/if}
    </div>
  </Dialog>
{/if}

{#if editingTheme}<ThemeEditor
    theme={activeTheme()}
    onclose={() => (editingTheme = false)}
  />{/if}
