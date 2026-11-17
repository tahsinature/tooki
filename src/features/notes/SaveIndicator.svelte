<script lang="ts">
  import { Check, LoaderCircle, CircleAlert } from '@lucide/svelte';
  let { status, onretry }: { status: string; onretry: () => void } = $props();
  let visible = $state(false);
  let previous = 'Saved';
  $effect(() => {
    const changed = status !== previous;
    previous = status;
    const pending = status === 'Saving…' || status === 'Not saved';
    visible = pending || changed;
    if (!pending && changed) {
      const timer = setTimeout(() => (visible = false), 1400);
      return () => clearTimeout(timer);
    }
  });
</script>

<div class="save-indicator" class:visible role="status" aria-live="polite">
  {#if status === 'Not saved'}
    <button
      class="icon-button"
      title="Not saved. Retry saving"
      aria-label="Retry saving note"
      onclick={onretry}><CircleAlert size={14} /></button
    >
  {:else}
    <span title={status} aria-label={status}>
      {#if status === 'Saving…'}<LoaderCircle
          class="saving-spinner"
          size={13}
        />{:else}<Check size={13} />{/if}
    </span>
  {/if}
</div>

<style>
  .save-indicator {
    display: grid;
    place-items: center;
    width: 22px;
    height: 24px;
    color: var(--muted);
    opacity: 0;
    transition: opacity 140ms;
  }
  .save-indicator.visible {
    opacity: 1;
  }
  span {
    display: grid;
    place-items: center;
  }
  .save-indicator :global(.saving-spinner) {
    animation: note-saving 1s linear infinite;
  }
  button {
    color: var(--danger);
  }
  @keyframes note-saving {
    to {
      transform: rotate(360deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .save-indicator {
      transition: none;
    }
    .save-indicator :global(.saving-spinner) {
      animation: none;
    }
  }
</style>
