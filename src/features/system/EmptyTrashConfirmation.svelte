<script lang="ts">
  import { onDestroy } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import ConfirmationActions from '../../components/ConfirmationActions.svelte';

  let {
    request,
    onclose,
  }: {
    request: number;
    onclose: () => void;
  } = $props();
  let resolved = false;
  let failed = $state(false);

  async function resolve(confirmed: boolean) {
    if (resolved) return;
    if (confirmed && failed) {
      // The previous attempt consumed its token, even if Finder canceled.
      // Request a new confirmation; never replay a consumed authorization.
      await invoke('execute_tool_command', { id: 'command:system.emptyTrash' });
      return;
    }
    resolved = true;
    try {
      await invoke('confirm_empty_trash', { request, confirmed });
    } catch (error) {
      resolved = false;
      failed = true;
      throw error;
    }
    onclose();
  }

  onDestroy(() => {
    if (!resolved)
      void invoke('confirm_empty_trash', { request, confirmed: false }).catch(
        console.error,
      );
  });
</script>

<ConfirmationActions
  title="Empty Trash?"
  description="Permanently delete all items in the Trash? This cannot be undone."
  confirmLabel={failed ? 'Try Again' : 'Empty Trash'}
  onclose={() => void resolve(false)}
  onconfirm={() => resolve(true)}
/>
