<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    title,
    onclose,
    children,
  }: {
    title: string;
    onclose: () => void;
    children: Snippet;
  } = $props();
  let surface: HTMLDivElement;
  function close() {
    onclose();
    document.getElementById('search')?.focus();
  }
</script>

<svelte:window
  onpointerdown={(event) => {
    const target = event.target as HTMLElement;
    if (
      surface &&
      !surface.contains(target) &&
      !target.closest('.footer-actions, .app-menu-trigger')
    )
      onclose();
  }}
/>
<div
  class="popup actions-popup"
  bind:this={surface}
  role="dialog"
  aria-label={title}
  tabindex="-1"
  onkeydown={(event) => {
    if (event.key === 'Escape' && !event.metaKey && !event.ctrlKey) {
      event.preventDefault();
      event.stopPropagation();
      close();
    }
  }}
>
  {@render children()}
</div>
