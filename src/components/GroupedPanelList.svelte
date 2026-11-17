<script lang="ts" generics="T extends { id: string }">
  import type { Snippet } from 'svelte';
  import SectionHeader from './SectionHeader.svelte';
  let { items, group, row, empty, label, element = $bindable() }: {
    items: T[]; group: (item: T) => string; row: Snippet<[T, number]>;
    empty: Snippet; label: string; element?: HTMLDivElement;
  } = $props();
</script>

<div class="result-list" bind:this={element} aria-label={label}>
  {#each items as item, index (item.id)}
    {#if group(item) && (index === 0 || group(item) !== group(items[index - 1]))}
      <SectionHeader title={group(item)} />
    {/if}
    {@render row(item, index)}
  {:else}
    {@render empty()}
  {/each}
</div>
