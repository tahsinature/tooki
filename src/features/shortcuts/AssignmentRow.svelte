<script lang="ts">
  import './assignment.css';
  import AssignmentIcon from './AssignmentIcon.svelte';
  import Button from '../../components/Button.svelte';
  import Keycap from '../../components/Keycap.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import ShortcutRecorder from '../../components/ShortcutRecorder.svelte';
  import { shortcutLabels } from '../../lib/shortcut';
  import { saveAssignment, type Assignment } from './assignments.svelte';
  let { item }: { item: Assignment } = $props();
  let editing = $state<'shortcut' | null>(null);
  let error = $state('');
  let busy = $state(false);
  async function update(values: { shortcut?: string }) {
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

<div class="assignment-row">
  <div class="assignment-label">
    <AssignmentIcon group={item.group} />
    <div class="assignment-name">
      <span>{item.title}</span>
      {#if item.unavailable || item.error}<p>
          {item.unavailable || item.error}
        </p>{/if}
    </div>
  </div>
  {#if item.unavailable}<span class="assignment-unavailable">Unavailable</span
    >{:else}
    <button
      class="assignment-control assignment-shortcut"
      class:unassigned={!item.shortcut}
      aria-label={'Edit shortcut for ' + item.title}
      title={'Edit shortcut for ' + item.title}
      onclick={() => {
        error = '';
        editing = 'shortcut';
      }}
    >
      {#if item.shortcut}{#each shortcutLabels(item.shortcut) as key}<Keycap
            text={key}
          />{/each}{:else}Record shortcut{/if}
    </button>
  {/if}
</div>
{#if editing}
  <Dialog title={'Shortcut for ' + item.title} onclose={() => (editing = null)}>
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
  </Dialog>
{/if}
