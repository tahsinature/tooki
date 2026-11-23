<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { ChevronDown } from '@lucide/svelte';
  import { observePortableConfig } from '../../lib/portableConfig';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import FilterPopup from '../../components/FilterPopup.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import Button from '../../components/Button.svelte';

  const id = $props.id();
  const options = [
    { value: '0', label: 'Never' },
    { value: '1', label: '1 minute' },
    { value: '5', label: '5 minutes' },
    { value: '15', label: '15 minutes' },
    { value: '30', label: '30 minutes' },
    { value: 'always', label: 'Always' },
    { value: 'custom', label: 'Custom…' },
  ];
  let minutes = $state<number | null>(5);
  let ready = $state(false);
  let busy = $state(false);
  let error = $state('');
  let opened = $state(false);
  let trigger = $state<HTMLButtonElement>();
  let custom = $state(false);
  let customMinutes = $state(5);
  let customValid = $derived(
    Number.isInteger(customMinutes) &&
      customMinutes >= 1 &&
      customMinutes <= 10080,
  );
  let value = $derived(minutes === null ? 'always' : String(minutes));
  let selected = $derived(
    options.some((option) => option.value === value) ? value : 'custom',
  );
  let label = $derived(
    options.find((option) => option.value === value)?.label ??
      `${minutes} minutes`,
  );

  async function refresh() {
    if (!isTauri() || busy) return;
    const settings = await invoke<{ launcher_session_minutes: number | null }>(
      'general_settings',
    );
    minutes = settings.launcher_session_minutes;
    ready = true;
  }
  onMount(() => observePortableConfig(refresh, (message) => (error = message)));

  function close(restore = false) {
    opened = false;
    if (restore) trigger?.focus();
  }
  async function save(next: number | null) {
    if (busy) return;
    busy = true;
    error = '';
    try {
      await invoke('set_launcher_session_timeout', { minutes: next });
      minutes = next;
      custom = false;
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
</script>

<SettingsRow
  title="Remember last session for"
  description="Starts when the launcher hides. After this time, the launcher shortcut opens fresh Root Search. Tool shortcuts always open fresh."
>
  <button
    class="control-button"
    bind:this={trigger}
    aria-label="Remember last session for"
    aria-haspopup="dialog"
    aria-expanded={opened}
    aria-controls={id}
    disabled={!ready || busy}
    onclick={() => (opened = !opened)}
    onkeydown={(event) => {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        opened = true;
      }
    }}>{label}<ChevronDown size={12} /></button
  >
  {#if opened && trigger}
    <FilterPopup
      {id}
      anchor={trigger}
      value={selected}
      label="Remember last session for"
      loadOptions={(query) =>
        options.filter((option) =>
          option.label.toLowerCase().includes(query.toLowerCase()),
        )}
      onchoose={(value) => {
        close(true);
        if (value === 'custom') {
          customMinutes = minutes && minutes > 0 ? minutes : 5;
          error = '';
          custom = true;
        } else if (options.some((option) => option.value === value)) {
          void save(value === 'always' ? null : Number(value));
        }
      }}
      onclose={close}
    />
  {/if}
</SettingsRow>
{#if error && !custom}<p class="settings-message" role="alert">{error}</p>{/if}
{#if custom}
  <Dialog
    title="Remember last session"
    onclose={() => {
      if (!busy) custom = false;
    }}
  >
    <form
      onsubmit={(event) => {
        event.preventDefault();
        if (customValid) void save(customMinutes);
      }}
    >
      <label for={`${id}-minutes`}>Minutes</label>
      <TextInput
        id={`${id}-minutes`}
        type="number"
        min={1}
        max={10080}
        step={1}
        bind:value={customMinutes}
        disabled={busy}
      />
      <p class="muted">
        Enter 1–10080 minutes. The timer starts when the launcher hides.
      </p>
      {#if error}<p class="settings-message" role="alert">{error}</p>{/if}
      <div class="dialog-actions">
        <Button disabled={busy} onclick={() => (custom = false)}>Cancel</Button>
        <Button type="submit" disabled={busy || !customValid}
          >{busy ? 'Saving…' : 'Save'}</Button
        >
      </div>
    </form>
  </Dialog>
{/if}
