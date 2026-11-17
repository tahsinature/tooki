<script lang="ts">
  import { Settings, Info, LogOut } from '@lucide/svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { getVersion } from '@tauri-apps/api/app';
  import { onMount } from 'svelte';
  import metadata from '../../package.json';
  import PopupSurface from './PopupSurface.svelte';
  import ActionsMenu from './ActionsMenu.svelte';
  let { onclose }: { onclose: () => void } = $props();
  let version = $state(metadata.version);
  let error = $state('');
  onMount(() => {
    if (isTauri())
      void getVersion()
        .then((value) => (version = value))
        .catch(console.error);
  });
  async function settings(page: string) {
    try {
      if (isTauri()) await invoke('open_settings', { page });
      else
        window.open(
          `?window=settings&page=${page}`,
          'tooki-settings',
          'width=800,height=590',
        );
      onclose();
    } catch {
      error = 'Could not open Settings.';
    }
  }
  async function quit() {
    try {
      await invoke('quit_app');
    } catch {
      error = 'Could not quit Tooki.';
    }
  }
</script>

<PopupSurface title="Tooki" {onclose}>
  <div class="app-menu-version">Tooki <span>Version {version}</span></div>
  <ActionsMenu
    actions={[
      {
        id: 'settings',
        label: 'Settings…',
        icon: Settings,
        run: () => void settings('general'),
      },
      {
        id: 'about',
        label: 'About Tooki',
        icon: Info,
        run: () => void settings('about'),
      },
      {
        id: 'quit',
        label: 'Quit Tooki',
        icon: LogOut,
        disabled: !isTauri(),
        run: () => void quit(),
      },
    ]}
  />
  {#if error}<p role="alert">{error}</p>{/if}
</PopupSurface>

<style>
  .app-menu-version {
    display: flex;
    justify-content: space-between;
    padding: 12px 14px;
    border-bottom: 1px solid var(--line);
    font-size: 12px;
  }
  .app-menu-version span {
    color: var(--muted);
  }
  p {
    padding: 8px 14px;
    color: var(--danger);
  }
</style>
