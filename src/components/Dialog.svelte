<script lang="ts">
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  let {
    title,
    children,
    onclose,
    icon,
  }: { title: string; children: Snippet; onclose: () => void; icon?: Snippet } =
    $props();
  let element: HTMLDialogElement;
  let headingHeight = $state(0);
  onMount(() => {
    element.showModal();
    element
      .querySelector<HTMLElement>(
        'input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [data-dialog-autofocus]:not([disabled])',
      )
      ?.focus();
    return () => element.close();
  });
</script>

<dialog
  bind:this={element}
  class="theme-dialog"
  style:--dialog-heading-height={`${headingHeight}px`}
  aria-label={title}
  {onclose}
  oncancel={(event) => {
    event.preventDefault();
    onclose();
  }}
>
  <div class="dialog-heading" bind:offsetHeight={headingHeight}>
    {#if icon}{@render icon()}{/if}
    <h2>{title}</h2>
  </div>
  {@render children()}
</dialog>
