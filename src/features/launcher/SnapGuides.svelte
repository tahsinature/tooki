<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  type Guides = {
    left: number;
    right: number;
    top: number;
    axes: { x: boolean; y: boolean };
  };
  let guides = $state<Guides | null>(null);
  onMount(() => {
    let disposed = false;
    let received = false;
    let stop: (() => void) | undefined;
    void (async () => {
      stop = await listen<Guides | null>('launcher-guides', (e) => {
        received = true;
        guides = e.payload;
      });
      if (disposed) {
        stop();
        return;
      }
      const initial = await invoke<Guides | null>('launcher_guides');
      if (!disposed && !received) guides = initial;
    })().catch(console.error);
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

{#if guides}
  <div
    class="guide vertical"
    class:active={guides.axes.x}
    style:left={`${guides.left}px`}
  ></div>
  <div
    class="guide vertical"
    class:active={guides.axes.x}
    style:left={`${guides.right}px`}
  ></div>
  <div
    class="guide horizontal"
    class:active={guides.axes.y}
    style:top={`${guides.top}px`}
  ></div>
{/if}

<style>
  :global(html),
  :global(body),
  :global(#app) {
    background: transparent !important;
    overflow: hidden;
    pointer-events: none;
  }
  .guide {
    position: fixed;
    opacity: 0;
    pointer-events: none;
    filter: drop-shadow(0 0 1px #000) drop-shadow(0 0 1px #000);
    transition: opacity 100ms ease;
  }
  .active {
    opacity: 1;
  }
  .vertical {
    top: 0;
    bottom: 0;
    border-left: 1.5px dashed rgba(255, 255, 255, 0.9);
  }
  .horizontal {
    left: 0;
    right: 0;
    border-top: 1.5px dashed rgba(255, 255, 255, 0.9);
  }
  @media (prefers-reduced-motion: reduce) {
    .guide {
      transition: none;
    }
  }
</style>
