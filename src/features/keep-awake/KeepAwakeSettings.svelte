<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import FilterPopup from '../../components/FilterPopup.svelte';
  import { ChevronDown } from '@lucide/svelte';
  import { observeKeepAwake } from './status.svelte';

  const { state: awake, refresh } = observeKeepAwake();
  let busy = $state(false);
  let error = $state('');
  let disabled = $derived(busy || !awake.value?.supported);
  const durationId = $props.id();
  const durations = [
    { value: 'On', label: 'Until turned off' },
    { value: '15', label: '15 minutes' },
    { value: '60', label: '1 hour' },
    { value: '120', label: '2 hours' },
  ];
  let durationOpen = $state(false);
  let durationTrigger = $state<HTMLButtonElement>();
  let duration = $derived(String(awake.value?.durationMinutes ?? 'On'));
  let minutesLeft = $derived(
    Math.ceil((awake.value?.remainingSeconds ?? 0) / 60),
  );
  let durationDescription = $derived(
    awake.value?.remainingSeconds == null
      ? 'Stops when you quit Tooki.'
      : `${minutesLeft} ${minutesLeft === 1 ? 'minute' : 'minutes'} remaining. Stops when you quit Tooki.`,
  );
  function closeDuration(restore = false) {
    durationOpen = false;
    if (restore) durationTrigger?.focus();
  }
  $effect(() => {
    if (!awake.value?.active) durationOpen = false;
  });
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

<SettingsSection title="Keep Awake">
  <SettingsRow
    title="Keep Mac awake"
    description={awake.value?.supported
      ? 'Prevent your Mac from sleeping automatically.'
      : awake.value || !isTauri()
        ? 'Available in the macOS desktop app.'
        : 'Checking availability…'}
  >
    <Toggle
      label="Keep Mac awake"
      checked={awake.value?.active ?? false}
      {disabled}
      onchange={(enabled) => run(enabled ? 'On' : 'Off')}
    />
  </SettingsRow>
  {#if awake.value?.active}
    <SettingsRow title="Duration" description={durationDescription}>
      <button
        class="control-button"
        bind:this={durationTrigger}
        aria-label="Keep Awake duration"
        aria-haspopup="dialog"
        aria-expanded={durationOpen}
        aria-controls={durationId}
        {disabled}
        onclick={() => (durationOpen = !durationOpen)}
      >
        {durations.find((option) => option.value === duration)?.label}
        <ChevronDown size={12} />
      </button>
      {#if durationOpen && durationTrigger}
        <FilterPopup
          id={durationId}
          anchor={durationTrigger}
          value={duration}
          label="Keep Awake duration"
          loadOptions={(query) =>
            durations.filter((option) =>
              option.label.toLowerCase().includes(query.toLowerCase()),
            )}
          onchoose={(value) => {
            closeDuration(true);
            if (durations.some((option) => option.value === value)) run(value);
          }}
          onclose={closeDuration}
        />
      {/if}
    </SettingsRow>
  {/if}
  <SettingsRow
    title="Also keep the screen on"
    description="Uses more battery and delays automatic screen locking."
  >
    <Toggle
      label="Also keep the screen on"
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
    title="Show menu bar icon"
    description="Quick controls while Keep Awake is on."
  >
    <Toggle
      label="Show Keep Awake menu bar icon"
      checked={awake.value?.showMenuBarIcon ?? true}
      {disabled}
      onchange={(visible) =>
        void perform(() => invoke('set_keep_awake_icon', { visible }))}
    />
  </SettingsRow>
</SettingsSection>
<p class="settings-note">
  Your Mac can still sleep when you close the lid or choose Sleep.
</p>
{#if error || awake.error}<p class="settings-message" role="alert">
    {error || awake.error}
  </p>{/if}

<ToolCommands tool="keepAwake" />
