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
  aria-label={title}
  {onclose}
  oncancel={(event) => {
    event.preventDefault();
    onclose();
  }}
>
  <div class="dialog-heading">
    {#if icon}{@render icon()}{/if}
    <h2>{title}</h2>
  </div>
  {@render children()}
</dialog>
