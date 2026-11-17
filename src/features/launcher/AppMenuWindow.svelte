<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import AppMenu from '../../components/AppMenu.svelte';
  import PopupWindow from '../../components/PopupWindow.svelte';
  let generation = $state(0);
  onMount(() => {
    let disposed = false;
    let stop: (() => void) | undefined;
    void listen('app-menu-opened', () => generation++).then((unlisten) => {
      if (disposed) unlisten();
      else stop = unlisten;
    });
    return () => {
      disposed = true;
      stop?.();
    };
  });
</script>

<PopupWindow
  onsize={(height) =>
    void invoke('resize_app_menu', { height }).catch(console.error)}
  >{#key generation}<AppMenu
      onclose={() => void invoke('close_app_menu', { restoreFocus: false })}
    />{/key}</PopupWindow
>
<svelte:window
  onkeydowncapture={(event) => {
    if (event.key === 'Escape') {
      event.preventDefault();
      event.stopImmediatePropagation();
      void invoke('close_app_menu', { restoreFocus: true });
    }
  }}
/>
