<script lang="ts">
  import type { Snippet } from 'svelte';
  let { label, children }: { label: string; children: Snippet } = $props();
</script>

<div class="floating-control-group" role="group" aria-label={label}>
  {@render children()}
</div>
