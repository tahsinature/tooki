<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import {
    RefreshCw,
    Folder,
    Copy,
    Star,
    Keyboard,
    Settings,
    Trash2,
    ExternalLink,
  } from '@lucide/svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import Button from '../../components/Button.svelte';
  import ShortcutRecorder from '../../components/ShortcutRecorder.svelte';
  import type { Item } from '../../lib/data';
  import {
    appPreferences,
    updateAppPreference,
  } from './app-preferences.svelte';
  let {
    item,
    onopen,
    onrefresh,
    refreshing = false,
    onclose,
    onstatus,
  }: {
    item: Item;
    onopen: () => void;
    onrefresh?: () => void;
    refreshing?: boolean;
    onclose: () => void;
    onstatus: (message: string) => void;
  } = $props();
  let id = $derived(item.id.slice(4));
  const mac = /Mac/.test(navigator.platform);
  const windows = /Win/.test(navigator.platform);
  let preference = $derived(appPreferences.values[id]);
  let editing = $state<'shortcut' | null>(null);
  let error = $state('');
  let busy = $state(false);
  let canUninstall = $state(false);
  onMount(() => {
    void invoke<string>('application_action', { id, operation: 'canUninstall' })
      .then((value) => (canUninstall = value === 'true'))
      .catch((reason) => (error = String(reason)));
  });
  async function perform(action: () => Promise<unknown>, message = '') {
    if (busy) return;
    busy = true;
    error = '';
    try {
      const result = await action();
      onstatus(message || (typeof result === 'string' ? result : ''));
      onclose();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  function native(operation: string) {
    return invoke<string>('application_action', { id, operation });
  }
</script>

{#if editing}
  <Dialog title={`Shortcut for ${item.title}`} onclose={() => (editing = null)}>
    <p class="shortcut-description">
      Open {item.title} from anywhere while Tooki is running.
    </p>
    <ShortcutRecorder
      externalError={preference?.shortcut_error ?? ''}
      label="Record application shortcut"
      loadShortcut={async () => preference?.shortcut ?? ''}
      saveShortcut={async (shortcut) => {
        await updateAppPreference(id, { shortcut });
        return shortcut;
      }}
    />
    <div class="dialog-actions">
      {#if preference?.shortcut}<Button
          disabled={busy}
          onclick={() =>
            void perform(
              () => updateAppPreference(id, { shortcut: '' }),
              'Shortcut removed.',
            )}>Remove shortcut</Button
        >{/if}<Button onclick={() => (editing = null)}>Done</Button>
    </div>
    {#if error}<p class="error-message" role="alert">{error}</p>{/if}
  </Dialog>
{:else}
  <PopupSurface title={item.title} {onclose}>
    <div class="application-heading">{item.title}</div>
    <ActionsMenu
      actions={[
        {
          id: 'open',
          label: 'Open Application',
          icon: ExternalLink,
          run: onopen,
          disabled: busy,
        },
        {
          id: 'reveal',
          label: mac ? 'Show in Finder' : 'Show in File Manager',
          icon: Folder,
          run: () => void perform(() => native('reveal')),
          disabled: busy,
        },
        {
          id: 'copy',
          label: windows ? 'Copy App Location' : 'Copy Path',
          icon: Copy,
          run: () =>
            void perform(
              async () => writeText(await native('location')),
              'Application location copied.',
            ),
          disabled: busy,
        },
        {
          id: 'favorite',
          label: preference?.favorite
            ? 'Remove from Favorites'
            : 'Add to Favorites',
          icon: Star,
          run: () =>
            void perform(() =>
              updateAppPreference(id, { favorite: !preference?.favorite }),
            ),
          disabled: busy,
        },
        {
          id: 'shortcut',
          label: preference?.shortcut ? 'Change Shortcut…' : 'Assign Shortcut…',
          icon: Keyboard,
          run: () => {
            error = '';
            editing = 'shortcut';
          },
          disabled: busy,
        },
        {
          id: 'settings',
          label: 'Settings…',
          icon: Settings,
          run: () =>
            void perform(() =>
              invoke('open_settings', { page: 'applications' }),
            ),
          disabled: busy,
        },
        ...(onrefresh
          ? [
              {
                id: 'refresh-applications',
                label: refreshing
                  ? 'Refreshing Applications…'
                  : 'Refresh Applications',
                icon: RefreshCw,
                run: onrefresh,
                disabled: refreshing,
              },
            ]
          : []),
        ...(canUninstall
          ? [
              {
                id: 'uninstall',
                label: 'Uninstall Application…',
                icon: Trash2,
                destructive: true,
                run: () =>
                  void perform(async () => {
                    return await native('uninstall');
                  }),
                disabled: busy,
              },
            ]
          : []),
      ]}
    />
    {#if error}<p class="application-error" role="alert">{error}</p>{/if}
  </PopupSurface>
{/if}

<style>
  .shortcut-description {
    margin: 0 0 12px;
    font-size: 12px;
    line-height: 1.5;
    color: var(--muted);
  }
  .application-heading {
    padding: 12px 14px;
    color: var(--muted);
    border-bottom: 1px solid var(--line);
    font-size: 12px;
  }
  .application-error {
    padding: 8px 14px;
    color: var(--danger);
    font-size: 12px;
  }
</style>
