<script lang="ts">
  import { Search } from '@lucide/svelte';
  import type { Snippet } from 'svelte';
  let {
    title = 'No results',
    description = 'Try another search or choose a different filter.',
    actions,
  }: {
    title?: string;
    description?: string;
    actions?: Snippet;
  } = $props();
</script>

<div class="empty" role="status">
  <div class="empty-icon" aria-hidden="true">
    <Search size={24} strokeWidth={1.4} />
  </div>
  <h2>{title}</h2>
  {#if description}<p>{description}</p>{/if}
  {#if actions}<div class="empty-actions">{@render actions()}</div>{/if}
</div>

<style>
  .empty {
    width: 100%;
    min-height: 180px;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 32px 24px;
    text-align: center;
    color: var(--muted);
  }
  .empty-icon {
    display: grid;
    place-items: center;
    width: 52px;
    height: 52px;
    margin-bottom: 18px;
    border: 1px solid var(--line);
    border-radius: var(--radius-card);
    background: linear-gradient(145deg, var(--panel), var(--surface));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--ink) 4%, transparent);
    color: var(--muted);
  }
  h2 {
    max-width: 32ch;
    margin: 0;
    font-size: 15px;
    line-height: 1.4;
    font-weight: 550;
    letter-spacing: -0.2px;
    color: var(--ink);
    text-wrap: balance;
  }
  p {
    max-width: 34ch;
    margin: 8px 0 0;
    font-size: 12px;
    line-height: 1.65;
    text-wrap: pretty;
  }
  .empty-actions {
    margin-top: 18px;
  }
</style>
