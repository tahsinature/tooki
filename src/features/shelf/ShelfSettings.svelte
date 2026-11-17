<script lang="ts">
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import { onMount } from 'svelte';
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  import TextInput from '../../components/TextInput.svelte';
  type Preferences = { enabled: boolean; executable: string };
  type Status = {
    preferences: Preferences;
    executable: string | null;
    available: boolean;
    reason: string | null;
    installCommand: string;
  };
  let connection = $state<Status | null>(null);
  let executable = $state('');
  let busy = $state(false);
  let message = $state('');
  let error = $state('');
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
    if (!isTauri()) return;
    connection = await invoke<Status>('shelferry_status');
    executable = connection.preferences.executable;
  }
  function save(enabled = connection?.preferences.enabled ?? true) {
    void perform(async () => {
      connection = await invoke<Status>('configure_shelferry', {
        preferences: { enabled, executable },
      });
      executable = connection.preferences.executable;
      message = 'Integration preferences saved.';
    });
  }
  function run(command: string) {
    void perform(async () => {
      await invoke('execute_tool_command', { id: `command:shelf.${command}` });
    });
  }
  onMount(() => {
    void perform(load);
  });
</script>

<SettingsSection
  title="Shelferry"
  description="An external-app extension. Your shelves live in Shelferry, ready to use from Tooki or on their own."
>
  <SettingsRow
    title="Enable extension"
    description="Add Shelferry commands to search and activate your assigned shortcuts."
  >
    <Toggle
      label="Enable Shelferry extension"
      checked={connection?.preferences.enabled ?? true}
      disabled={busy || !connection}
      onchange={save}
    />
  </SettingsRow>
  <SettingsRow
    title={connection?.available ? 'Ready to use' : 'Connection'}
    description={connection?.reason ??
      (connection?.available
        ? 'Shelferry opens automatically when you run a command.'
        : isTauri()
          ? 'Checking Shelferry…'
          : 'Available in the macOS desktop app.')}
  >
    <Button
      disabled={busy || !isTauri()}
      onclick={() =>
        void perform(async () => {
          connection = await invoke<Status>('check_shelferry');
          if (connection.available) message = 'Connected to Shelferry.';
        })}>Check Connection</Button
    >
  </SettingsRow>
  <SettingsRow
    title="Shelferry preferences"
    description="Configure floating shelves, appearance, and Shelferry’s own shortcuts in its app."
  >
    <Button
      disabled={busy || !connection?.available}
      onclick={() => run('settings')}>Open Settings</Button
    >
  </SettingsRow>
  <SettingsRow
    title="Shelf Manager"
    description="Open your shelves. Run the command again to hide the manager."
  >
    <Button
      disabled={busy || !connection?.available}
      onclick={() => run('open')}>Open Manager</Button
    >
  </SettingsRow>
</SettingsSection>

<SettingsSection
  title="Executable"
  description="Leave blank to find Shelferry automatically in Homebrew or Applications."
>
  <SettingsRow
    title="CLI override"
    description={connection?.executable
      ? `Using ${connection.executable}`
      : 'Enter the full path to the shelferry executable if installed elsewhere.'}
  >
    <div class="executable-control">
      <TextInput
        class="text-field"
        aria-label="Shelferry executable override"
        placeholder="Automatic"
        bind:value={executable}
        disabled={busy || !isTauri()}
      />
      <Button disabled={busy || !connection} onclick={() => save()}>Save</Button
      >
    </div>
  </SettingsRow>
  {#if connection && !connection.available && connection.preferences.enabled}
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
          })}>Copy Command</Button
      >
    </SettingsRow>
  {/if}
</SettingsSection>
{#if error}<p class="settings-message" role="alert">{error}</p>{/if}
{#if message}<p class="settings-message" role="status">{message}</p>{/if}
<ToolCommands tool="shelf" />
<p class="section-description">
  Your existing Tooki shelves and files are preserved. They have not been
  migrated to Shelferry.
</p>

<style>
  .executable-control {
    display: flex;
    align-items: center;
    gap: 8px;
  }
</style>
