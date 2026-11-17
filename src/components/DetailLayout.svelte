<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    children,
    information,
    label = 'Detail preview',
  }: {
    children: Snippet;
    information: Snippet;
    label?: string;
  } = $props();
</script>

<aside class="detail" aria-label={label}>
  <div class="detail-preview">{@render children()}</div>
  {@render information()}
</aside>
