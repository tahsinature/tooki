<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import { Download, CircleCheck, RefreshCw } from '@lucide/svelte';
  import Button from '../../components/Button.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';

  let { installUnavailable }: { installUnavailable: string | null } = $props();
  type Release = {
    latestVersion: string;
    status: 'available' | 'current' | 'ahead';
    releaseTag: string;
    updateCommand: string | null;
    signedUpdate: boolean;
  };
  type InstallStatus = {
    phase:
      | 'idle'
      | 'checking'
      | 'downloading'
      | 'verifying'
      | 'installing'
      | 'restarting'
      | 'failed';
    downloaded: number;
    total: number | null;
    error: string | null;
  };
  let checking = $state(false);
  let release = $state<Release | null>(null);
  let error = $state('');
  let copied = $state(false);
  let install = $state<InstallStatus>({
    phase: 'idle',
    downloaded: 0,
    total: null,
    error: null,
  });
  let starting = $state(false);
  const busy = $derived(
    starting || !['idle', 'failed'].includes(install.phase),
  );
  const percent = $derived(
    install.total
      ? Math.min(100, Math.floor((install.downloaded / install.total) * 100))
      : null,
  );
  const progressText = $derived(
    install.phase === 'downloading'
      ? `Downloading update${percent !== null ? ` · ${percent}%` : '…'}`
      : install.phase === 'verifying'
        ? 'Verifying signature…'
        : install.phase === 'installing'
          ? 'Installing update…'
          : install.phase === 'restarting'
            ? 'Restarting Tooki…'
            : 'Preparing update…',
  );
  const title = $derived(
    busy
      ? progressText
      : checking
        ? 'Checking for updates…'
        : release?.status === 'available'
          ? `Tooki ${release.latestVersion} is available`
          : release?.status === 'current'
            ? 'You’re up to date'
            : release?.status === 'ahead'
              ? 'You’re ahead of the latest release'
              : 'Software update',
  );

  onMount(() => {
    if (!isTauri()) return;
    let disposed = false;
    let unlisten: (() => void) | undefined;
    let received = false;
    void (async () => {
      const stop = await listen<InstallStatus>(
        'update-install-status',
        ({ payload }) => {
          received = true;
          install = payload;
        },
      );
      if (disposed) {
        stop();
        return;
      }
      unlisten = stop;
      const status = await invoke<InstallStatus>('update_install_status');
      if (!disposed && !received) install = status;
    })().catch((reason) => {
      error = String(reason);
    });
    return () => {
      disposed = true;
      unlisten?.();
    };
  });

  async function check() {
    if (checking || busy) return;
    checking = true;
    error = '';
    copied = false;
    release = null;
    try {
      release = await invoke<Release>('check_for_updates');
    } catch (reason) {
      error = String(reason);
    } finally {
      checking = false;
    }
  }
  async function update() {
    if (!release || busy || installUnavailable || !release.signedUpdate) return;
    starting = true;
    error = '';
    try {
      await invoke('install_update', { version: release.latestVersion });
    } catch (reason) {
      error = String(reason);
    } finally {
      starting = false;
    }
  }
  async function copyCommand() {
    if (!release?.updateCommand) return;
    try {
      await writeText(release.updateCommand);
      copied = true;
      error = '';
    } catch {
      error = 'Could not copy the command. Try again.';
    }
  }
  async function openNotes() {
    if (!release) return;
    try {
      await invoke('open_release_notes', { tag: release.releaseTag });
      error = '';
    } catch (reason) {
      error = String(reason);
    }
  }
</script>

<SettingsSection>
  <div class="update-card" aria-busy={checking || busy}>
    <div class="update-summary">
      <span class="update-symbol" aria-hidden="true">
        {#if release?.status === 'current' && !busy}<CircleCheck
            size={22}
          />{:else if busy || checking}<RefreshCw size={22} />{:else}<Download
            size={22}
          />{/if}
      </span>
      <div class="update-description" role="status" aria-live="polite">
        <h2>{title}</h2>
        <p>
          {#if busy}Tooki will reopen when the update is ready.{:else if installUnavailable}{installUnavailable}{:else if release?.status === 'available' && !release.signedUpdate}This
            release requires Homebrew. Future signed releases can install here.{:else if release?.status === 'ahead'}Latest
            public version: {release.latestVersion}.{:else if release?.status === 'current'}You
            have the latest public release.{:else}Download verified updates
            directly in Tooki.{/if}
        </p>
      </div>
    </div>
    {#if busy}<progress
        aria-label={progressText}
        max="100"
        value={install.phase === 'downloading' && percent !== null
          ? percent
          : undefined}
      ></progress>{/if}
    {#if error || install.error}<p class="update-error" role="alert">
        {error || install.error}
      </p>{/if}
    <div class="update-actions">
      {#if !busy}
        {#if release?.status === 'available' && release.signedUpdate && !installUnavailable}
          <Button onclick={update}>Update &amp; Restart</Button>
        {:else}
          <Button disabled={checking || !isTauri()} onclick={check}
            >{checking ? 'Checking…' : 'Check for Updates'}</Button
          >
        {/if}
        {#if release}<Button onclick={openNotes}>Release Notes</Button>{/if}
      {/if}
    </div>
    {#if release?.status === 'available' && release.updateCommand && !busy && !installUnavailable}
      <details class="manual-update">
        <summary>Update using Homebrew</summary>
        <div>
          <code>{release.updateCommand}</code><Button onclick={copyCommand}
            >{copied ? 'Copied' : 'Copy Command'}</Button
          >
        </div>
      </details>
    {/if}
  </div>
</SettingsSection>

<style>
  .update-card {
    padding: 20px 16px;
  }
  .update-summary {
    display: flex;
    align-items: flex-start;
    gap: 14px;
  }
  .update-symbol {
    color: var(--muted);
    display: grid;
    place-items: center;
    padding-top: 2px;
    flex: none;
  }
  .update-description {
    flex: 1;
    min-width: 0;
  }
  h2 {
    margin: 0 0 6px;
    font-size: 14px;
    font-weight: 600;
  }
  p {
    color: var(--muted);
    font-size: 12px;
    line-height: 1.6;
    margin: 0;
  }
  .update-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 18px;
    padding-left: 36px;
  }
  .update-actions:empty {
    display: none;
  }
  progress {
    width: calc(100% - 36px);
    height: 5px;
    margin: 18px 0 0 36px;
    accent-color: var(--accent);
  }
  .update-error {
    margin: 14px 0 0 36px;
    color: var(--ink);
    overflow-wrap: anywhere;
    user-select: text;
  }
  .manual-update {
    margin: 18px 0 0 36px;
    color: var(--muted);
    font-size: 11px;
  }
  summary {
    cursor: pointer;
  }
  .manual-update div {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
    margin-top: 12px;
  }
  code {
    overflow-wrap: anywhere;
    user-select: text;
  }
</style>
