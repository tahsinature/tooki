<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  import { observeKeepAwake, statusText } from './status.svelte';

  const { state: awake, refresh } = observeKeepAwake();
  let busy = $state(false);
  let error = $state('');
  let disabled = $derived(busy || !awake.value?.supported);
  async function perform(action: () => Promise<unknown>) {
    if (busy) return;
    busy = true;
    error = '';
    try {
      await action();
      await refresh();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  function run(suffix: string) {
    void perform(() =>
      invoke('execute_tool_command', {
        id: `command:system.keepAwake${suffix}`,
      }),
    );
  }
</script>

<SettingsSection
  title="Keep Awake"
  description="Prevent idle sleep while Tooki is running. Sessions end when you quit and do not resume on launch."
>
  <SettingsRow
    title="Status"
    description={awake.value
      ? statusText(awake.value)
      : isTauri()
        ? 'Checking status…'
        : 'Available in the macOS desktop app.'}
  >
    <Button
      disabled={disabled || !awake.value?.active}
      onclick={() => run('Off')}>Turn Off</Button
    >
  </SettingsRow>
  <SettingsRow
    title="Show coffee icon in the menu bar"
    description="Appears only while Keep Awake is active, with duration controls and a Turn Off action."
  >
    <Toggle
      label="Show Keep Awake menu bar icon"
      checked={awake.value?.showMenuBarIcon ?? true}
      {disabled}
      onchange={(visible) =>
        void perform(() => invoke('set_keep_awake_icon', { visible }))}
    />
  </SettingsRow>
  <SettingsRow
    title="Keep display awake"
    description="Off by default so the display can sleep. Enabling this also affects automatic screen locking and uses more battery."
  >
    <Toggle
      label="Keep display awake"
      checked={awake.value?.mode === 'display'}
      {disabled}
      onchange={(enabled) =>
        void perform(() =>
          invoke('set_keep_awake_mode', {
            mode: enabled ? 'display' : 'system',
          }),
        )}
    />
  </SettingsRow>
  <SettingsRow
    title="Start a session"
    description="Starting again replaces the current timer. Changing display mode preserves the time remaining."
  >
    <div class="awake-durations">
      <Button {disabled} onclick={() => run('15')}>15 Minutes</Button>
      <Button {disabled} onclick={() => run('60')}>1 Hour</Button>
      <Button {disabled} onclick={() => run('120')}>2 Hours</Button>
      <Button {disabled} onclick={() => run('On')}>Until Turned Off</Button>
    </div>
  </SettingsRow>
</SettingsSection>
<p class="settings-note">
  Keep Awake prevents idle sleep. It does not override Sleep commands or
  closed-lid sleep. Display mode resets to off when Tooki restarts.
</p>
{#if error || awake.error}<p class="settings-message" role="alert">
    {error || awake.error}
  </p>{/if}

<ToolCommands tool="keepAwake" />

<style>
  .awake-durations {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-end;
    gap: 6px;
  }
</style>
