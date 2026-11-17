<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  import Keycap from '../../components/Keycap.svelte';
  type Status = {
    enabled: boolean;
    active: boolean;
    available: boolean;
    helperRequired: boolean;
    permissionRequired: boolean;
    error: string;
  };
  let hyperStatus = $state<Status>({
    enabled: false,
    active: false,
    available: false,
    helperRequired: false,
    permissionRequired: false,
    error: '',
  });
  let loaded = $state(false);
  let busy = $state(true),
    error = $state('');
  async function request(operation: string, enabled?: boolean) {
    busy = true;
    error = '';
    try {
      hyperStatus = await invoke('hyper_request', { operation, enabled });
      loaded = true;
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
  onMount(() => {
    void request('status');
    let disposed = false;
    let stop: (() => void) | undefined;
    void listen('hyper-changed', () => {
      if (!busy) void request('status');
    })
      .then((unlisten) => {
        if (disposed) unlisten();
        else stop = unlisten;
      })
      .catch(console.error);
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<svelte:window
  onfocus={() => {
    if (!busy) void request('recheck');
  }}
/>

<SettingsSection title="Hyper Key">
  <SettingsRow
    title="Use Caps Lock as Hyper"
    description="Hold Caps Lock while pressing another key to combine Control, Alt/Option, Shift and Super/Command."
  >
    {#if loaded}<Toggle
        label="Enable Hyper Key"
        checked={hyperStatus.enabled}
        disabled={busy || !hyperStatus.available}
        onchange={(value) => void request('set', value)}
      />{:else}<span role="status"
        >{busy ? 'Loading…' : 'Status unavailable'}</span
      >{/if}
  </SettingsRow>
  {#if hyperStatus.available}
    <SettingsRow
      title="Status"
      description={hyperStatus.permissionRequired && hyperStatus.enabled
        ? 'Allow Accessibility access so Tooki can remap Caps Lock. Enable Tooki in System Settings, then return here.'
        : hyperStatus.active
          ? hyperStatus.enabled
            ? 'Hyper Key is running.'
            : 'Remapping is still running. Retry to finish disabling it.'
          : hyperStatus.enabled
            ? 'Enabled in preferences. Remapping is not running.'
            : 'Hyper Key is off.'}
    >
      {#if hyperStatus.permissionRequired}
        <Button disabled={busy} onclick={() => void request('openPermissions')}
          >Open Accessibility Settings</Button
        >
      {:else if hyperStatus.error || hyperStatus.enabled !== hyperStatus.active}
        <Button disabled={busy} onclick={() => void request('retry')}
          >Retry</Button
        >
      {:else}<span role="status">{hyperStatus.active ? 'Active' : 'Off'}</span
        >{/if}
    </SettingsRow>
  {/if}
  <SettingsRow
    title="Tap Caps Lock"
    description="A quick tap keeps the usual Caps Lock behavior."
    ><Keycap text="Caps Lock" /></SettingsRow
  >
</SettingsSection>
{#if hyperStatus.helperRequired}
  <SettingsSection title="Linux helper">
    <SettingsRow
      title="Optional keyd configuration"
      description="Remapping runs below X11 and Wayland. Review and install the helper separately with administrator permission."
      ><Button disabled={busy} onclick={() => void request('exportHelper')}
        >Export configuration…</Button
      ></SettingsRow
    >
  </SettingsSection>
  <p class="settings-note">
    Install keyd using your distribution’s package manager. Merge the exported
    settings into your existing /etc/keyd configuration, or install it as
    tooki-hyper.conf if no configuration exists. Validate with keyd check, then
    reload the service. The helper runs independently of Tooki. To disable it,
    remove the Tooki bindings and reload keyd.
  </p>
{:else}
  <p class="settings-note">
    Disable Caps Lock remapping in other apps first. macOS requires
    Accessibility permission and reserves F18 while enabled. Windows remapping
    does not reach elevated apps or the secure desktop. Remapping stops when
    Tooki quits.
  </p>
{/if}
{#if error || hyperStatus.error}<p class="settings-message" role="alert">
    {error || hyperStatus.error}
  </p>{/if}
