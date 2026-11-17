<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import Dialog from '../../components/Dialog.svelte';
  import Button from '../../components/Button.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';

  type Status = {
    supported: boolean;
    granted: boolean;
    prompt: boolean;
    build: string;
    appPath: string;
  };
  let status = $state<Status | null>(null);
  let busy = $state(false);
  let error = $state('');
  async function request(operation: string) {
    if (!isTauri()) return;
    try {
      status = await invoke<Status>('permission_request', { operation });
      error = '';
    } catch (reason) {
      error = String(reason);
    }
  }
  async function openSettings() {
    busy = true;
    await request('open');
    busy = false;
  }
  onMount(() => {
    if (!isTauri()) return;
    let disposed = false;
    let stop: (() => void) | undefined;
    void listen<Status>('permissions-changed', ({ payload }) => {
      status = payload;
    })
      .then(async (unlisten) => {
        if (disposed) {
          unlisten();
          return;
        }
        stop = unlisten;
        await request('ready');
      })
      .catch((reason) => {
        error = String(reason);
      });
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<svelte:window
  onfocus={() => {
    if (status && !busy) void request('status');
  }}
/>

{#if status?.supported && !status.granted}
  <SettingsSection title="Permission needed">
    <SettingsRow
      title="Allow Accessibility access"
      description="Pasting, automatic snippet expansion and Hyper Key need access. Copy remains available."
    >
      <Button onclick={() => void request('show')}>Review Access</Button>
    </SettingsRow>
  </SettingsSection>
  {#if status.prompt}
    <Dialog
      title="Allow Accessibility access"
      onclose={() => {
        if (!busy) void request('dismiss');
      }}
    >
      <p class="settings-note">
        Tooki needs Accessibility access to paste into other apps, expand
        snippets while you type and use Hyper Key.
      </p>
      <p class="settings-note">
        Enable this copy of Tooki in System Settings → Privacy &amp; Security →
        Accessibility. If it isn’t listed, use the + button to add it.
      </p>
      <p class="settings-note">
        {status.build} app: <span class="app-path">{status.appPath}</span>
      </p>
      <p class="settings-note">
        Tooki will check again automatically. Copy and other tools remain
        available if you choose Later.
      </p>
      {#if error}<p class="error-message" role="alert">{error}</p>{/if}
      <div class="dialog-actions">
        <Button disabled={busy} onclick={() => void request('dismiss')}
          >Later</Button
        >
        <Button disabled={busy} onclick={openSettings}
          >Open Accessibility Settings</Button
        >
      </div>
    </Dialog>
  {/if}
{/if}
{#if error && !status?.prompt}<p class="error-message" role="alert">
    {error}
  </p>{/if}

<style>
  .app-path {
    overflow-wrap: anywhere;
    user-select: text;
  }
</style>
