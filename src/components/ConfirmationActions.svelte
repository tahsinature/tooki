<script lang="ts">
  import type { Snippet } from 'svelte';
  import { Trash2 } from '@lucide/svelte';
  import Dialog from './Dialog.svelte';
  import Button from './Button.svelte';
  let {
    title,
    description,
    confirmLabel,
    onconfirm,
    onclose,
    children,
  }: {
    title: string;
    description: string;
    confirmLabel: string;
    onconfirm: () => void | Promise<void>;
    onclose: () => void;
    children?: Snippet;
  } = $props();
  let busy = $state(false);
  let error = $state('');
  function cancel() {
    if (!busy) onclose();
  }
  async function confirm() {
    if (busy) return;
    busy = true;
    error = '';
    try {
      await onconfirm();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
</script>

<Dialog {title} onclose={cancel}>
  {#snippet icon()}<div class="confirmation-icon" aria-hidden="true">
      <Trash2 size={18} strokeWidth={1.8} />
    </div>{/snippet}
  <p class="confirmation-description">{description}</p>
  {#if children}<div class="confirmation-options">
      {@render children()}
    </div>{/if}
  {#if error}<p class="error-message" role="alert">{error}</p>{/if}
  <div class="dialog-actions">
    <Button disabled={busy} onclick={cancel}>Cancel</Button>
    <Button destructive disabled={busy} onclick={() => void confirm()}
      >{busy ? 'Working…' : confirmLabel}</Button
    >
  </div>
</Dialog>

<style>
  .confirmation-icon {
    display: grid;
    place-items: center;
    width: 24px;
    height: 24px;
    flex-shrink: 0;
    color: var(--muted);
  }
  .confirmation-description {
    margin: 0;
    font-size: 13px;
    line-height: 1.5;
    color: var(--muted);
  }
  .confirmation-options {
    margin-top: 14px;
    font-size: 12px;
    color: var(--muted);
  }

  :global(.theme-dialog:has(.confirmation-description)) {
    width: min(360px, calc(100vw - 32px));
    padding: 20px;
  }
  :global(.theme-dialog:has(.confirmation-description) .dialog-heading) {
    justify-content: flex-start;
    gap: 8px;
    top: -20px;
    padding: 20px 0 8px;
    margin: -20px 0 0;
  }
  :global(.theme-dialog:has(.confirmation-description) .dialog-heading h2) {
    font-size: 14px;
    line-height: 24px;
    font-weight: 600;
  }
  :global(.theme-dialog:has(.confirmation-description) .dialog-actions) {
    gap: 8px;
    margin-top: 20px;
    margin-bottom: -20px;
    padding: 0 0 20px;
    bottom: -20px;
    border-top: 0;
    flex-wrap: wrap;
  }
  :global(
    .theme-dialog:has(.confirmation-description) .dialog-actions > :first-child
  ) {
    margin-right: 0;
  }
  :global(.theme-dialog:has(.confirmation-description) .control-button) {
    min-height: 30px;
    padding: 6px 12px;
    font-size: 12px;
    white-space: normal;
  }
  :global(
    .theme-dialog:has(.confirmation-description) .control-button.destructive
  ) {
    background: color-mix(in srgb, var(--danger) 12%, transparent);
    border-color: transparent;
    font-weight: 500;
  }
</style>
