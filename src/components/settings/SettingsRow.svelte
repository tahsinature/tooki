<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    title,
    description,
    children,
    help,
  }: {
    title: string;
    description?: string;
    help?: Snippet;
    children?: Snippet;
  } = $props();
</script>

<div class="settings-row">
  <div class="settings-row-copy">
    <span>{title}</span>{#if help}
      {@render help()}{/if}{#if description}<p>{description}</p>{/if}
  </div>
  {#if children}<div class="settings-row-control">
      {@render children()}
    </div>{/if}
</div>
