<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import Button from '../../components/Button.svelte';

  type Release = {
    latestVersion: string;
    status: 'available' | 'current' | 'ahead';
    releaseTag: string;
    updateCommand: string | null;
  };
  let checking = $state(false);
  let release = $state<Release | null>(null);
  let error = $state('');
  let copied = $state(false);

  async function check() {
    if (checking) return;
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
  async function copyCommand() {
    if (!release?.updateCommand) return;
    try {
      await writeText(release.updateCommand);
      copied = true;
      error = '';
    } catch {
      error = 'Could not copy the update command. Select and copy it below.';
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

<div class="update-check" aria-busy={checking}>
  <Button disabled={checking || !isTauri()} onclick={check}>
    {checking ? 'Checking…' : 'Check for Updates'}
  </Button>
  <div role="status" aria-live="polite">
    {#if release}
      {#if release.status === 'available'}
        <p>Tooki {release.latestVersion} is available.</p>
      {:else if release.status === 'ahead'}
        <p>
          This build is newer than the latest release ({release.latestVersion}).
        </p>
      {:else}
        <p>You’re up to date.</p>
      {/if}
    {/if}
  </div>
  {#if release}
    <div class="update-actions">
      <Button onclick={openNotes}>Release Notes</Button>
      {#if release.status === 'available' && release.updateCommand}
        <Button onclick={copyCommand}
          >{copied ? 'Copied' : 'Copy Update Command'}</Button
        >
      {/if}
    </div>
    {#if release.status === 'available' && release.updateCommand}
      <code>{release.updateCommand}</code>
      <p class="settings-note">
        Updates are installed through Homebrew. A newly published release may
        take a few minutes to appear there.
      </p>
    {/if}
  {/if}
  {#if error}<p class="settings-message" role="alert">{error}</p>{/if}
</div>

<style>
  .update-check {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    max-width: 100%;
    text-align: center;
  }
  .update-actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 8px;
  }
  code {
    font-size: 12px;
    color: var(--ink);
    overflow-wrap: anywhere;
    user-select: text;
  }
  [role='status']:empty {
    display: none;
  }
</style>
