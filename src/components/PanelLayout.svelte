<script lang="ts">
  import type { Snippet } from 'svelte';
  let { header, children, footer, overlay }: {
    header: Snippet; children: Snippet; footer: Snippet; overlay?: Snippet;
  } = $props();
</script>

<main class="app-shell">
  {@render header()}
  {@render children()}
  {@render footer()}
  {@render overlay?.()}
</main>
