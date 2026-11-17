<script lang="ts">
  import { untrack } from 'svelte';
  import { request, type Library } from './api';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  let {
    library,
    onrefresh,
  }: { library: Library; onrefresh: () => Promise<void> } = $props();
  let busy = $state(false),
    error = $state('');
  let exclusions = $state(
    untrack(() => library.preferences.excludedApps.join('\n')),
  );
  async function perform(operation: string, args: unknown = {}) {
    busy = true;
    error = '';
    try {
      await request(operation, args);
      await onrefresh();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
</script>

<SettingsSection
  title="Automatic expansion"
  description="Use your snippets while typing in other apps. Press Space after a trigger to expand it."
>
  <SettingsRow
    title="Expand while typing"
    description={library.status.supported
      ? library.preferences.automatic
        ? library.status.active
          ? 'Listening for your enabled triggers.'
          : 'Waiting for Accessibility access. Your text remains unchanged until expansion is available.'
        : 'Off. Snippets are still available from the launcher.'
      : 'Automatic expansion requires macOS. The snippet library and Copy work on this platform.'}
  >
    <Toggle
      label="Automatic snippet expansion"
      disabled={busy || !library.status.supported}
      checked={library.preferences.automatic}
      onchange={(automatic) =>
        void perform('preferences', { ...library.preferences, automatic })}
    />
  </SettingsRow>
  {#if library.status.supported}<SettingsRow
      title="Accessibility access"
      description={library.status.permission
        ? 'Granted. Secure input and password fields are excluded.'
        : 'Needed to recognize triggers and replace text in supported text fields.'}
      ><div class="snippet-button-row">
        {#if !library.status.permission}<Button
            disabled={busy}
            onclick={() => void perform('permission')}>Allow Access</Button
          >{/if}<Button disabled={busy} onclick={() => void perform('recheck')}
          >Recheck</Button
        >
      </div></SettingsRow
    >{/if}
</SettingsSection>
<details class="snippet-advanced">
  <summary>Excluded apps</summary>
  <p class="snippet-hint">
    Never expand in these apps. Enter one bundle identifier per line, such as <code
      >com.apple.Terminal</code
    >.
  </p>
  <textarea
    class="text-field"
    aria-label="Excluded application bundle identifiers"
    bind:value={exclusions}
    rows="3"
    spellcheck="false"></textarea><Button
    disabled={busy}
    onclick={() =>
      void perform('preferences', {
        ...library.preferences,
        excludedApps: exclusions
          .split('\n')
          .map((value) => value.trim())
          .filter(Boolean),
      })}>Save Exclusions</Button
  >
</details>
{#if error}<p class="error-message" role="alert">{error}</p>{/if}
