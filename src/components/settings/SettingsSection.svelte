<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    title,
    description,
    children,
  }: { title?: string; description?: string; children: Snippet } = $props();
</script>

<section class="settings-section" aria-label={title}>
  {#if title}<h2>{title}</h2>{/if}
  {#if description}<p class="section-description">{description}</p>{/if}
  <div class="settings-section-body">{@render children()}</div>
</section>
