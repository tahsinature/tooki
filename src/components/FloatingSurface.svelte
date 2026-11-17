<script lang="ts">
  import { onMount, type Snippet } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import './floating-chrome.css';
  let {
    keepOnTop = false,
    label,
    class: className = '',
    children,
  }: {
    keepOnTop?: boolean;
    label: string;
    class?: string;
    children: Snippet;
  } = $props();
  $effect(() => {
    const enabled = keepOnTop;
    if (isTauri())
      void invoke('set_utility_on_top', { enabled }).catch(console.error);
  });
  let focused = $state(false);
  onMount(() => {
    if (!isTauri()) {
      focused = true;
      return;
    }
    let disposed = false;
    let received = false;
    let stop: (() => void) | undefined;
    const window = getCurrentWindow();
    void window
      .onFocusChanged(({ payload }) => {
        received = true;
        if (!disposed) focused = payload;
      })
      .then(async (unlisten) => {
        if (disposed) {
          unlisten();
          return;
        }
        stop = unlisten;
        const current = await window.isFocused();
        if (!disposed && !received) focused = current;
      })
      .catch(console.error);
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<main
  class={`floating-surface ${className}`}
  class:focused
  class:native-material={isTauri() && navigator.platform.includes('Mac')}
  aria-label={label}
>
  {@render children()}
</main>
