<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Button from '../../components/Button.svelte';
  let busy = $state(false);
  let message = $state('');
  let failed = $state(false);
  async function reset() {
    if (busy) return;
    busy = true;
    message = '';
    failed = false;
    try {
      await invoke('reset_launcher_layout');
      message = 'Launcher size and position reset.';
    } catch (error) {
      failed = true;
      message = String(error);
    } finally {
      busy = false;
    }
  }
</script>

<SettingsRow
  title="Reset launcher size & position"
  description="Restore the default size and center the launcher on its current display. Your search and tool stay unchanged."
>
  <Button disabled={!isTauri() || busy} onclick={() => void reset()}
    >{busy ? 'Resetting…' : 'Reset'}</Button>
</SettingsRow>
{#if message}<p class="settings-message" class:error-message={failed} role="status">{message}</p>{/if}
