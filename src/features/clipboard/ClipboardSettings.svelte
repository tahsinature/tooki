<script lang="ts">
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import { onMount } from 'svelte';
  import { isTauri } from '@tauri-apps/api/core';
  import { request, type ClipboardSettings } from './api';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import ConfirmationActions from '../../components/ConfirmationActions.svelte';
  let settings = $state<ClipboardSettings>();
  let error = $state('');
  let saving = $state(false);
  let clear = $state(false);
  let includePinned = $state(false);
  onMount(() => {
    if (isTauri())
      void request<ClipboardSettings>('settings')
        .then((value) => (settings = value))
        .catch((e) => (error = String(e)));
    else error = 'Clipboard capture settings are available in the desktop app.';
  });
  async function save(patch: Partial<ClipboardSettings>) {
    if (!settings || saving) return;
    saving = true;
    error = '';
    try {
      settings = await request('saveSettings', { ...settings, ...patch });
    } catch (e) {
      error = String(e);
    } finally {
      saving = false;
    }
  }
  async function clearHistory() {
    try {
      await request('clear', { includePinned });
      clear = false;
    } catch (e) {
      error = String(e);
    }
  }
</script>

{#if settings}
  <fieldset disabled={saving} class="clipboard-settings">
    <SettingsSection title="Capture">
      <SettingsRow
        title="Monitor clipboard"
        description="Capture text, links, images, and copied files."
        ><Toggle
          label="Monitor clipboard"
          checked={settings.enabled}
          onchange={(enabled) => void save({ enabled })}
        /></SettingsRow
      >
      <SettingsRow
        title="Recognize text in images"
        description="Uses on-device recognition. Image text becomes searchable."
        ><Toggle
          label="Recognize text in images"
          checked={settings.ocrEnabled}
          onchange={(ocrEnabled) => void save({ ocrEnabled })}
        /></SettingsRow
      >
    </SettingsSection>
    <SettingsSection title="History">
      <SettingsRow
        title="Save history between launches"
        description="Turn off for session-only history. Pinned items follow this setting too."
        ><Toggle
          label="Save history between launches"
          checked={settings.persistHistory}
          onchange={(persistHistory) => void save({ persistHistory })}
        /></SettingsRow
      >
      <SettingsRow
        title="Maximum items"
        description="Pinned items are kept outside these limits."
        ><TextInput
          class="clipboard-limit"
          aria-label="Maximum items"
          type="number"
          min="1"
          max="100000"
          value={settings.maxItems}
          onchange={(e) =>
            void save({ maxItems: Number(e.currentTarget.value) })}
        /></SettingsRow
      >
      <SettingsRow title="Maximum images"
        ><TextInput
          class="clipboard-limit"
          aria-label="Maximum images"
          type="number"
          min="0"
          max="10000"
          value={settings.maxImages}
          onchange={(e) =>
            void save({ maxImages: Number(e.currentTarget.value) })}
        /></SettingsRow
      >
      <SettingsRow
        title="Keep history for days"
        description="0 keeps items until the item limit is reached."
        ><TextInput
          class="clipboard-limit"
          aria-label="Retention days"
          type="number"
          min="0"
          max="3650"
          value={settings.retentionDays}
          onchange={(e) =>
            void save({ retentionDays: Number(e.currentTarget.value) })}
        /></SettingsRow
      >
      <SettingsRow title="Clear clipboard history"
        ><button class="secondary-button" onclick={() => (clear = true)}
          >Clear History…</button
        ></SettingsRow
      >
    </SettingsSection>
    <SettingsSection title="Privacy">
      <SettingsRow
        title="Excluded applications"
        description="One macOS bundle identifier per line. Concealed and transient clipboard content is always skipped."
      />
      <textarea
        class="clipboard-exclusions"
        aria-label="Excluded applications"
        rows="4"
        value={settings.ignoredApps.join('\n')}
        onchange={(e) =>
          void save({
            ignoredApps: e.currentTarget.value
              .split('\n')
              .map((s) => s.trim())
              .filter(Boolean),
          })}></textarea>
    </SettingsSection>
  </fieldset>
{/if}
{#if error}<p class="settings-message" role="alert">{error}</p>{/if}
{#if clear}<ConfirmationActions
    title="Clear clipboard history?"
    description="Saved clips will be permanently removed. Original files stay untouched."
    confirmLabel={includePinned
      ? 'Clear History Including Pinned'
      : 'Clear Unpinned History'}
    onclose={() => (clear = false)}
    onconfirm={clearHistory}
  >
    <label
      ><input type="checkbox" bind:checked={includePinned} /> Include pinned items</label
    >
  </ConfirmationActions>{/if}

<ToolCommands tool="clipboard" />
