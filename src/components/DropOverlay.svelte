<script lang="ts">
  import { Download } from '@lucide/svelte';
  let { saving = false }: { saving?: boolean } = $props();
</script>

<div class="drop-overlay" role="status" aria-live="polite" aria-busy={saving}>
  <div class="drop-target">
    <Download size={32} strokeWidth={1.5} aria-hidden="true" />
    <strong>{saving ? 'Adding to history…' : 'Drop to add to history'}</strong>
    <span
      >{saving
        ? 'Saving a copy. Your originals stay where they are.'
        : 'Files, folders, images, text, and links'}</span
    >
  </div>
</div>

<style>
  .drop-overlay {
    position: absolute;
    inset: 0;
    z-index: 30;
    display: grid;
    padding: 16px;
    background: color-mix(in srgb, var(--surface) 94%, transparent);
  }
  .drop-target {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    border: 2px dashed var(--accent);
    border-radius: var(--row-radius);
    color: var(--accent);
  }
  strong {
    font-size: 18px;
    font-weight: 600;
    color: var(--ink);
  }
  span {
    font-size: 13px;
    color: var(--muted);
  }
</style>
