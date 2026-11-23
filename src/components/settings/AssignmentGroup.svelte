<script lang="ts">
  import type { Snippet } from 'svelte';
  let { title, children }: { title: string; children: Snippet } = $props();
</script>

<section class="assignment-group" aria-label={title}>
  {@render children()}
</section>

<style>
  .assignment-group {
    margin: 0;
    padding: 3px 0;
  }
  :global(.assignment-group) + .assignment-group {
    border-top: 1px solid var(--line);
  }
</style>
