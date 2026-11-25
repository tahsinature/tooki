<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    children,
    detail,
    empty,
  }: { children: Snippet; detail?: Snippet; empty?: Snippet } = $props();
</script>

<div class="workspace" class:split={!!detail && !empty}>
  {#if empty}
    <div class="panel-empty">{@render empty()}</div>
  {:else}
    {@render children()}
    {@render detail?.()}
  {/if}
</div>

<style>
  .panel-empty {
    flex: 1;
    min-width: 0;
    min-height: 0;
    display: grid;
    place-items: center;
    overflow: auto;
  }
</style>
