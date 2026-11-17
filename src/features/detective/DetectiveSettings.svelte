<script lang="ts">
  import TextInput from '../../components/TextInput.svelte';
  import { onMount, onDestroy } from 'svelte';
  import { isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { Keyboard, Search } from '@lucide/svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import InfoPopover from '../../components/InfoPopover.svelte';
  import Button from '../../components/Button.svelte';
  import ActivityLog from '../../components/activity-log/ActivityLog.svelte';
  import { logEntries, logColumns, logFilters } from './log';
  import { request, comboFromEvent, type Snapshot, mergeSnapshot } from './api';
  import './detective.css';
  const native = isTauri();
  let snapshot = $state<Snapshot | null>(null);
  let mode = $state<'observe' | 'block'>('observe');
  let busy = $state(false);
  let error = $state('');
  let disposed = false;
  let unlisten: (() => void) | undefined;
  let entries = $derived(
    logEntries(snapshot?.checks ?? [], snapshot?.capabilities.platform ?? ''),
  );
  let localLookup = $derived(
    mode === 'block' && !snapshot?.capabilities.canBlock,
  );
  function apply(incoming: Snapshot) {
    if (!disposed) snapshot = mergeSnapshot(snapshot, incoming);
  }
  onMount(() => {
    if (!native) return;
    void (async () => {
      try {
        let initialized = false;
        const pending: Snapshot[] = [];
        const stop = await listen<Snapshot>('detective-changed', (event) => {
          if (initialized) apply(event.payload);
          else pending.push(event.payload);
        });
        if (disposed) {
          stop();
          return;
        }
        unlisten = stop;
        apply(await request('status'));
        initialized = true;
        pending.forEach(apply);
        if (!snapshot?.capabilities.canObserve) mode = 'block';
      } catch (reason) {
        if (!disposed) error = String(reason);
      }
    })();
  });
  onDestroy(() => {
    disposed = true;
    unlisten?.();
    if (native) void request('stop').catch(() => {});
  });
  async function act(operation: string) {
    busy = true;
    error = '';
    try {
      apply(await request(operation, mode));
      if (disposed && operation === 'start') await request('stop');
    } catch (reason) {
      if (!disposed) error = String(reason);
    } finally {
      busy = false;
    }
  }
  async function capture(event: KeyboardEvent) {
    // Tab remains normal focus navigation. Browser handlers never claim to block OS shortcuts.
    if (event.key === 'Tab') return;
    const combo = comboFromEvent(event);
    if (!combo) return;
    event.preventDefault();
    event.stopPropagation();
    if (busy) return;
    busy = true;
    error = '';
    try {
      apply(await request('lookup', undefined, combo));
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
</script>

<div class="detective-page settings-fill-page">
  <div>
    <SettingsSection>
      <SettingsRow
        title="Find what takes a shortcut"
        description={snapshot?.listening
          ? 'Listening across apps. Switch to another app and press a shortcut.'
          : 'Check known assignments and observe shortcuts across apps.'}
      >
        {#snippet help()}
          <InfoPopover title="How detection works">
            <p>
              {snapshot?.capabilities.explanation ??
                'Check known assignments or observe shortcut delivery while listening.'}
            </p>
            <p>
              Results stay in memory until you clear them or quit Tooki.
              Listening stops when you leave this page, close Settings, or after
              five minutes.
            </p>
            <p>
              Earlier interceptors and secure input can prevent Tooki from
              seeing a press. Known assignments do not prove which app
              intercepted a shortcut.
            </p>
          </InfoPopover>
        {/snippet}
        {#if !localLookup}<Button
            disabled={!native ||
              !snapshot ||
              busy ||
              (!snapshot.listening && !snapshot.capabilities.canObserve)}
            onclick={() => void act(snapshot?.listening ? 'stop' : 'start')}
            >{snapshot?.listening
              ? 'Stop listening'
              : 'Start listening'}</Button
          >{/if}
      </SettingsRow>
      <div class="detective-modes" role="group" aria-label="Detection mode">
        <button
          class:chosen={mode === 'observe'}
          aria-pressed={mode === 'observe'}
          disabled={busy ||
            snapshot?.listening ||
            !snapshot?.capabilities.canObserve}
          onclick={() => (mode = 'observe')}
          ><Keyboard size={15} /><span
            ><strong>Run shortcut</strong><small
              >The shortcut executes while Tooki observes it.</small
            ></span
          ></button
        >
        <button
          class:chosen={mode === 'block'}
          aria-pressed={mode === 'block'}
          disabled={busy || snapshot?.listening}
          onclick={() => (mode = 'block')}
          ><Search size={15} /><span
            ><strong>Look up shortcut</strong><small
              >{snapshot?.capabilities.canBlock
                ? 'Block received presses and check known assignments.'
                : 'Check a shortcut in the focused field below.'}</small
            ></span
          ></button
        >
      </div>
      {#if localLookup}
        <div class="detective-local">
          <label for="detective-lookup">Press a shortcut to look it up</label>
          <TextInput
            id="detective-lookup"
            class="text-field"
            readonly
            value=""
            placeholder="Click here, then press your shortcut…"
            onkeydown={capture}
            disabled={!native || !snapshot}
          />
          <p class="settings-note">
            System-reserved shortcuts may still run and may never reach this
            field.
          </p>
        </div>
      {/if}
    </SettingsSection>
    {#if error}<p class="error-message" role="alert">{error}</p>{/if}
    {#if snapshot?.message && snapshot.message !== error}<p
        class="settings-note"
        role="status"
      >
        {snapshot.message}
      </p>{/if}
    {#if !native}<p class="settings-note">
        Keyboard detection is available in the desktop app.
      </p>{/if}
  </div>
  <div class="detective-log">
    <ActivityLog
      {entries}
      columns={logColumns}
      filters={logFilters}
      title="Results"
      filename="shortcut-detective.json"
      emptyMessage={snapshot?.listening
        ? 'Listening… Switch to an app and press a shortcut.'
        : 'Start listening to see shortcut results here.'}
      onclear={async () => apply(await request('clear'))}
    />
  </div>
</div>
