<script lang="ts">
  import LauncherSessionSettings from './LauncherSessionSettings.svelte';
  import ConfigurationSettings from './ConfigurationSettings.svelte';
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import AssignmentRow from '../shortcuts/AssignmentRow.svelte';
  import { launcherRow } from '../shortcuts/assignments.svelte';
  import Keycap from '../../components/Keycap.svelte';
  type Status = { launch_at_login: boolean; show_tray: boolean };
  let status = $state<Status>({ launch_at_login: false, show_tray: false });
  let ready = $state(false);
  let busy = $state(false);
  let error = $state('');
  const mac = /Mac/.test(navigator.platform);
  async function refresh() {
    if (!isTauri() || busy) return;
    try {
      status = await invoke('general_settings');
      ready = true;
      error = '';
    } catch (reason) {
      error = String(reason);
    }
  }
  onMount(() => {
    void refresh();
  });
  async function change(setting: keyof Status, enabled: boolean) {
    busy = true;
    error = '';
    try {
      status = await invoke('set_general_setting', { setting, enabled });
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
</script>

<svelte:window onfocus={() => void refresh()} />
<SettingsSection title="Startup">
  <SettingsRow
    title="Launch at login"
    description="Start Tooki in the background when you sign in."
  >
    <Toggle
      label="Launch at login"
      checked={status.launch_at_login}
      disabled={!ready || busy}
      onchange={(value) => void change('launch_at_login', value)}
    />
  </SettingsRow>
  <SettingsRow
    title={mac ? 'Show menu bar icon' : 'Show tray icon'}
    description="Quick access to Tooki, Settings and Quit. Your launcher shortcut works even when this is hidden."
  >
    <Toggle
      label={mac ? 'Show menu bar icon' : 'Show tray icon'}
      checked={status.show_tray}
      disabled={!ready || busy}
      onchange={(value) => void change('show_tray', value)}
    />
  </SettingsRow>
</SettingsSection>
<SettingsSection title="Launcher">
  <AssignmentRow item={launcherRow()} />
  <LauncherSessionSettings />
  <SettingsRow title="Open Settings"
    ><Keycap text={mac ? '⌘' : 'Ctrl'} /><Keycap text="," /></SettingsRow
  >
</SettingsSection>
{#if error}<p class="settings-message" role="alert">{error}</p>{/if}

<ConfigurationSettings />
