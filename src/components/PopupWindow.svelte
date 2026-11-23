<script lang="ts">
  import { onMount, type Snippet } from 'svelte';
  let {
    children,
    onsize,
  }: { children: Snippet; onsize?: (height: number) => void } = $props();
  let host: HTMLDivElement;
  onMount(() => {
    if (!onsize) return;
    let previous = 0;
    function measure() {
      const popup = host.querySelector<HTMLElement>('.popup');
      if (!popup) return;
      const style = getComputedStyle(popup);
      let height =
        parseFloat(style.borderTopWidth) +
        parseFloat(style.borderBottomWidth) +
        2;
      for (const child of Array.from(popup.children)) {
        const css = getComputedStyle(child);
        let size = child.getBoundingClientRect().height;
        if (child.classList.contains('actions-list')) {
          size =
            Array.from(child.children).reduce(
              (sum, row) => sum + row.getBoundingClientRect().height,
              0,
            ) +
            parseFloat(css.paddingTop) +
            parseFloat(css.paddingBottom);
          size = Math.min(size, parseFloat(css.maxHeight));
        }
        height +=
          size + parseFloat(css.marginTop) + parseFloat(css.marginBottom);
      }
      height = Math.ceil(height);
      if (height !== previous) {
        previous = height;
        onsize?.(height);
      }
    }
    const observer = new MutationObserver(measure);
    observer.observe(host, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    measure();
    return () => observer.disconnect();
  });
</script>

<div class="popup-window" bind:this={host}>{@render children()}</div>

<style>
  .popup-window {
    padding: 1px;
    height: 100dvh;
  }
  /* A native popup supplies positioning; its content uses the shared surface. */
  .popup-window :global(.popup) {
    position: relative;
    inset: auto;
    width: 100%;
    height: 100%;
    max-height: none;
    max-width: none;
    box-shadow: none;
  }
  .popup-window :global(.filter-options) {
    flex: 1;
  }
</style>
