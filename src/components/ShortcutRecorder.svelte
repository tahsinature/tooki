<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { Keyboard } from '@lucide/svelte';
  import Keycap from './Keycap.svelte';
  import { shortcutFromEvent, shortcutLabels } from '../lib/shortcut';
  let {
    loadShortcut,
    saveShortcut,
    label = 'Record launcher shortcut',
    externalError = '',
  }: {
    loadShortcut?: () => Promise<string>;
    saveShortcut?: (shortcut: string) => Promise<string>;
    label?: string;
    externalError?: string;
  } = $props();
  let current = $state('');
  let draft = $state('');
  let recording = $state(false);
  let busy = $state(false);
  let error = $state('');
  const native = isTauri();
  onMount(() => {
    if (native)
      void (
        loadShortcut ? loadShortcut() : invoke<string>('get_launcher_shortcut')
      )
        .then((value) => (current = value))
        .catch((reason) => (error = String(reason)));
  });
  onDestroy(() => {
    if (native) void invoke('set_shortcut_recording', { recording: false });
  });
  async function start() {
    busy = true;
    try {
      await invoke('set_shortcut_recording', { recording: true });
      draft = '';
      error = '';
      recording = true;
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  async function cancel() {
    try {
      await invoke('set_shortcut_recording', { recording: false });
      recording = false;
      draft = '';
    } catch (reason) {
      error = String(reason);
    }
  }
  async function save() {
    busy = true;
    try {
      current = saveShortcut
        ? await saveShortcut(draft)
        : await invoke<string>('set_launcher_shortcut', { shortcut: draft });
      await cancel();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  function capture(event: KeyboardEvent) {
    if (!recording) return;
    if (
      !event.metaKey &&
      !event.ctrlKey &&
      !event.altKey &&
      !event.shiftKey &&
      ['Enter', ' '].includes(event.key) &&
      (event.target as HTMLElement)?.closest('[data-recorder-action]')
    )
      return;
    if (event.key === 'Tab') {
      event.stopImmediatePropagation();
      return;
    }
    event.preventDefault();
    event.stopImmediatePropagation();
    if (event.key === 'Escape') {
      void cancel();
      return;
    }
    if (busy || event.repeat) return;
    const value = shortcutFromEvent(event);
    if (value) {
      draft = value;
      error = '';
    } else if (!['Meta', 'Control', 'Alt', 'Shift'].includes(event.key))
      error = 'Include Command, Control, or Option with a key.';
  }
</script>

<svelte:window
  onkeydowncapture={capture}
  onblur={() => {
    if (recording && !busy) void cancel();
  }}
/>
<div class="shortcut-recorder">
  <button
    class="shortcut-record-button"
    data-dialog-autofocus
    class:recording
    aria-label={label}
    aria-pressed={recording}
    disabled={!native || busy}
    onclick={start}
  >
    <Keyboard size={16} aria-hidden="true" />
    <span class="shortcut-record-value">
      {#if recording && !draft}Press your shortcut…
      {:else if !(draft || current)}Click to record
      {:else}{#each shortcutLabels(draft || current) as key}<Keycap
            text={key}
          />{/each}{/if}
    </span>
    {#if busy}<span class="shortcut-record-hint">Please wait…</span>
    {:else if current && !recording}<span class="shortcut-record-hint"
        >Change</span
      >{/if}
  </button>
  {#if !native}<small>Available in the desktop app.</small>
  {:else if recording}<small
      >Press a combination, then Save. Escape cancels.</small
    >{/if}
  {#if error || externalError}<small role="alert"
      >{error || externalError}</small
    >{/if}
  {#if recording}<div class="shortcut-recorder-controls">
      <button
        type="button"
        class="control-button"
        data-recorder-action
        disabled={busy}
        onclick={cancel}>Cancel</button
      >
      <button
        type="button"
        class="control-button"
        data-recorder-action
        disabled={!draft || busy}
        onclick={save}>Save shortcut</button
      >
    </div>{/if}
</div>
