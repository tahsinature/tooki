<script lang="ts" module>
  export type { FilterOption } from './FilterPopupContent.svelte';
</script>

<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { listen, emitTo } from '@tauri-apps/api/event';
  import FilterPopupContent, {
    type FilterOption,
  } from './FilterPopupContent.svelte';
  let props: {
    id: string;
    anchor: HTMLElement;
    placement?: 'anchor' | 'window';
    value: string;
    label: string;
    placeholder?: string;
    emptyMessage?: string;
    loadOptions: (query: string) => FilterOption[] | Promise<FilterOption[]>;
    onchoose: (value: string) => void;
    onhighlight?: (value: string | null) => void;
    onclose: (restoreFocus: boolean) => void;
  } = $props();
  const session = crypto.randomUUID();
  onMount(() => {
    if (!isTauri()) return;
    let disposed = false;
    const stops: (() => void)[] = [];
    async function start() {
      for (const subscription of [
        listen<{ session: string; value: string | null }>(
          'filter-highlighted',
          ({ payload }) => {
            if (payload.session === session && !disposed)
              props.onhighlight?.(payload.value);
          },
        ),
        listen<{ session: string; key: string; meta: boolean; ctrl: boolean }>(
          'filter-shortcut',
          ({ payload }) => {
            if (payload.session !== session || disposed) return;
            props.onclose(false);
            window.dispatchEvent(
              new KeyboardEvent('keydown', {
                key: payload.key,
                metaKey: payload.meta,
                ctrlKey: payload.ctrl,
                bubbles: true,
                cancelable: true,
              }),
            );
          },
        ),
        listen<{ session: string; query: string; request: number }>(
          'filter-query',
          async ({ payload }) => {
            if (payload.session !== session || disposed) return;
            let options: FilterOption[] = [];
            let error = '';
            try {
              options = await props.loadOptions(payload.query);
            } catch (reason) {
              error = String(reason);
            }
            if (!disposed)
              await emitTo('filter-popup', 'filter-results', {
                session,
                request: payload.request,
                options,
                error,
              });
          },
        ),
        listen<{ session: string; value?: string; restore: boolean }>(
          'filter-closed',
          ({ payload }) => {
            if (payload.session !== session || disposed) return;
            if (payload.value !== undefined) props.onchoose(payload.value);
            else props.onclose(payload.restore);
          },
        ),
      ]) {
        const stop = await subscription;
        if (disposed) stop();
        else stops.push(stop);
      }
      if (disposed) return;
      const rect = props.anchor.getBoundingClientRect();
      await invoke('open_filter_popup', {
        request: {
          session,
          placement: props.placement ?? 'anchor',
          id: props.id,
          value: props.value,
          label: props.label,
          placeholder: props.placeholder ?? 'Type to filter…',
          emptyMessage: props.emptyMessage ?? 'No matching options',
          anchor: { x: rect.right, y: rect.top, height: rect.height },
        },
      });
      if (disposed)
        await invoke('close_filter_popup', { session, restore: false });
    }
    void start().catch((error) => {
      console.error(error);
      if (!disposed) props.onclose(false);
    });
    return () => {
      disposed = true;
      stops.forEach((stop) => stop());
      void invoke('close_filter_popup', { session, restore: false });
    };
  });
</script>

{#if !isTauri()}<FilterPopupContent {...props} />{/if}
