<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import { Layers } from '@lucide/svelte';
  import { onMount } from 'svelte';
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import type { Extension } from './catalog';

  let { extension }: { extension: Extension } = $props();
  type Preferences = { enabled: boolean; executable: string };
  type ConnectionState =
    'ready' | 'notInstalled' | 'disabled' | 'unsupported' | 'needsAttention';
  type Status = {
    preferences: Preferences;
    executable: string | null;
    available: boolean;
    supported: boolean;
    state: ConnectionState;
    reason: string | null;
    installCommand: string;
  };
  const labels: Record<ConnectionState, string> = {
    ready: 'Ready',
    notInstalled: 'Not installed',
    disabled: 'Disabled',
    unsupported: 'Unsupported',
    needsAttention: 'Needs attention',
  };
  let connection = $state<Status | null>(null);
  let executable = $state('');
  let busy = $state(false);
  let message = $state('');
  let error = $state('');
  let connectionState = $derived(error ? 'needsAttention' : connection?.state);
  async function perform(action: () => Promise<void>) {
    if (busy) return;
    busy = true;
    error = '';
    message = '';
    try {
      await action();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  async function load() {
    if (isTauri()) connection = await invoke<Status>('shelferry_status');
  }
  function save(
    enabled = connection?.preferences.enabled ?? true,
    path = connection?.preferences.executable ?? '',
  ) {
    void perform(async () => {
      connection = await invoke<Status>('configure_shelferry', {
        preferences: { enabled, executable: path },
      });
      executable = connection.preferences.executable;
      message = 'Extension preferences saved.';
    });
  }
  function run(command: string) {
    void perform(async () => {
      await invoke('execute_tool_command', { id: `command:shelf.${command}` });
    });
  }
  onMount(() => {
    void perform(async () => {
      await load();
      executable = connection?.preferences.executable ?? '';
    });
    let disposed = false;
    let stop: (() => void) | undefined;
    if (isTauri())
      void listen('command-support-changed', () => {
        if (!busy) void perform(load);
      }).then((unlisten) => {
        if (disposed) unlisten();
        else stop = unlisten;
      });
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<header class="extension-header">
  <span class="extension-icon"><Layers size={30} strokeWidth={1.6} /></span>
  <div class="extension-heading">
    <span class="extension-kind">{extension.kind} · {extension.platform}</span>
    <h2>{extension.name}</h2>
    <span
      class="connection-state"
      class:ready={connectionState === 'ready'}
      role="status"
    >
      <span class="status-dot"></span>
      {connectionState
        ? labels[connectionState]
        : isTauri()
          ? 'Checking…'
          : 'Desktop app required'}
    </span>
  </div>
  <Toggle
    label="Enable Shelferry extension"
    checked={connection?.preferences.enabled ?? false}
    disabled={busy || !connection?.supported}
    onchange={(enabled) => save(enabled)}
  />
</header>
<p class="extension-description">{extension.description}</p>

<SettingsSection title="Connection">
  <SettingsRow
    title={connection?.preferences.enabled
      ? 'Enabled in Tooki'
      : 'Enable in Tooki'}
    description={connection?.reason ??
      (connection?.available
        ? 'Commands are available in search and through your assigned shortcuts. Shelferry starts when needed.'
        : 'Enable this extension in the header to use its commands. Requires the Shelferry macOS app.')}
  >
    <Button
      disabled={busy ||
        !connection?.supported ||
        !connection.preferences.enabled}
      onclick={() =>
        void perform(async () => {
          connection = await invoke<Status>('check_shelferry');
          if (connection.available) message = 'Connected to Shelferry.';
        })}>Check Connection</Button
    >
  </SettingsRow>
  {#if connection?.state === 'notInstalled'}
    <SettingsRow
      title="Install Shelferry"
      description={connection.installCommand}
    >
      <Button
        disabled={busy}
        onclick={() =>
          void perform(async () => {
            await writeText(connection!.installCommand);
            message =
              'Install command copied. Run it in Terminal, then check the connection.';
          })}>Copy Install Command</Button
      >
    </SettingsRow>
  {/if}
</SettingsSection>
{#if error}<p class="error-message" role="alert">{error}</p>{/if}
{#if message}<p class="settings-message" role="status">{message}</p>{/if}

<SettingsSection title="Open in Shelferry">
  <SettingsRow
    title="Shelf Manager"
    description="Browse your shelves. Run again to hide the manager."
  >
    <Button
      disabled={busy || !connection?.available}
      onclick={() => run('open')}>Open Manager</Button
    >
  </SettingsRow>
  <SettingsRow
    title="Shelferry Settings"
    description="Shelf appearance, behavior, and the app’s own shortcuts."
  >
    <Button
      disabled={busy || !connection?.available}
      onclick={() => run('settings')}>Open Settings</Button
    >
  </SettingsRow>
</SettingsSection>
<ToolCommands tool={extension.tool} />

<details class="extension-advanced">
  <summary>Advanced</summary>
  <SettingsSection
    title="Executable"
    description="Leave blank to find Shelferry in Homebrew or Applications."
  >
    <SettingsRow
      title="CLI override"
      description={connection?.executable
        ? `Using ${connection.executable}`
        : 'Use the full path if installed elsewhere.'}
    >
      <Button
        disabled={busy || !connection?.supported}
        onclick={() => save(undefined, executable)}>Save</Button
      >
    </SettingsRow>
    <div class="executable-input">
      <TextInput
        class="text-field"
        aria-label="Shelferry executable override"
        placeholder="Automatic"
        bind:value={executable}
        disabled={busy || !connection?.supported}
      />
    </div>
  </SettingsSection>
</details>
<p class="settings-note">
  Shelferry owns your shelf windows and files. Disabling this extension only
  disconnects it from Tooki. Existing Tooki shelves remain untouched.
</p>

<style>
  .extension-header {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .extension-icon {
    display: grid;
    place-items: center;
    flex: none;
    width: 58px;
    height: 58px;
    border-radius: var(--radius-card);
    background: color-mix(in srgb, #00bccb 15%, var(--panel));
    color: #00bccb;
    border: 1px solid color-mix(in srgb, #00bccb 30%, var(--line));
  }
  .extension-heading {
    flex: 1;
    min-width: 0;
  }
  .extension-heading h2 {
    font-size: 22px;
    letter-spacing: -0.5px;
    margin: 4px 0 6px;
  }
  .extension-kind {
    color: var(--muted);
    font-size: 10px;
  }
  .connection-state {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    color: var(--muted);
    font-size: 11px;
  }
  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: currentColor;
  }
  .connection-state.ready {
    color: var(--accent);
  }
  .extension-description {
    color: var(--muted);
    line-height: 1.7;
    margin: 18px 0 24px;
    max-width: 48ch;
  }
  .extension-advanced {
    border-top: 1px solid var(--line);
    padding-top: 14px;
    margin: 6px 0 18px;
  }
  summary {
    cursor: pointer;
    color: var(--muted);
    font-weight: 500;
    padding: 4px 0;
  }
  summary:focus-visible {
    outline: 1px solid var(--input-focus-border);
    outline-offset: 4px;
  }
  .extension-advanced[open] summary {
    margin-bottom: 14px;
  }
  .executable-input {
    padding: 0 12px 12px;
  }
  .executable-input :global(input) {
    width: 100%;
  }
</style>
