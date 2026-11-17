<script lang="ts">
  import type { Snippet } from 'svelte';
  let { children, detail }: { children: Snippet; detail?: Snippet } = $props();
</script>

<div class="workspace" class:split={!!detail}>
  {@render children()}
  {@render detail?.()}
</div>
