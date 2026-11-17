<script lang="ts">
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Button from '../../components/Button.svelte';
  import Keycap from '../../components/Keycap.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import ShortcutRecorder from '../../components/ShortcutRecorder.svelte';
  import { shortcutLabels } from '../../lib/shortcut';
  import { saveAssignment, type Assignment } from './assignments.svelte';
  let { item }: { item: Assignment } = $props();
  let editing = $state<'alias' | 'shortcut' | null>(null);
  let alias = $state('');
  let error = $state('');
  let busy = $state(false);
  async function update(values: { alias?: string; shortcut?: string }) {
    busy = true;
    error = '';
    try {
      await saveAssignment(item, values);
      editing = null;
    } catch (cause) {
      error = String(cause);
    } finally {
      busy = false;
    }
  }
</script>

<SettingsRow title={item.title} description={item.unavailable || item.error}>
  {#if item.unavailable}<span class="settings-note" aria-disabled="true"
      >Unavailable</span
    >{:else}
    {#if !item.launcher}<Button
        label={'Edit alias for ' + item.title}
        onclick={() => {
          alias = item.alias;
          error = '';
          editing = 'alias';
        }}>{item.alias || 'Add alias'}</Button
      >{/if}
    <Button
      label={'Edit shortcut for ' + item.title}
      onclick={() => {
        error = '';
        editing = 'shortcut';
      }}
    >
      {#if item.shortcut}{#each shortcutLabels(item.shortcut) as key}<Keycap
            text={key}
          />{/each}{:else}Add shortcut{/if}
    </Button>
  {/if}
</SettingsRow>
{#if editing}
  <Dialog
    title={(editing === 'alias' ? 'Alias for ' : 'Shortcut for ') + item.title}
    onclose={() => (editing = null)}
  >
    {#if editing === 'alias'}
      <form
        onsubmit={(event) => {
          event.preventDefault();
          void update({ alias });
        }}
      >
        <label class="field-label" for={'alias-' + item.id}>Search alias</label>
        <TextInput
          id={'alias-' + item.id}
          class="text-field"
          bind:value={alias}
          maxlength={80}
          placeholder="e.g. newnote"
        />
        <p class="settings-note">
          Type this alias in Root Search. Clear it to remove it.
        </p>
        {#if error}<p role="alert" class="error-message">{error}</p>{/if}
        <div class="dialog-actions">
          <Button onclick={() => (editing = null)}>Cancel</Button><Button
            type="submit"
            disabled={busy}>Save alias</Button
          >
        </div>
      </form>
    {:else}
      <p class="settings-note">
        Run this command from anywhere while Tooki is running.
      </p>
      <ShortcutRecorder
        label={'Record shortcut for ' + item.title}
        externalError={item.error}
        loadShortcut={async () => item.shortcut}
        saveShortcut={async (shortcut) => {
          await saveAssignment(item, { shortcut });
          return shortcut;
        }}
      />
      {#if error}<p role="alert" class="error-message">{error}</p>{/if}
      <div class="dialog-actions">
        {#if item.shortcut && (!item.launcher || item.customized)}<Button
            disabled={busy}
            onclick={() => void update({ shortcut: '' })}
            >{item.launcher ? 'Reset to default' : 'Remove shortcut'}</Button
          >{/if}
        <Button onclick={() => (editing = null)}>Done</Button>
      </div>
    {/if}
  </Dialog>
{/if}
