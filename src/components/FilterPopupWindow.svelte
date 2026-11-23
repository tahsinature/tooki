<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import PopupWindow from './PopupWindow.svelte';
  import FilterPopupContent, {
    type FilterOption,
  } from './FilterPopupContent.svelte';
  type Request = {
    session: string;
    id: string;
    value: string;
    label: string;
    placeholder: string;
    emptyMessage: string;
  };
  let current = $state<Request | null>(null);
  let anchor = $state<HTMLDivElement>(null!);
  let sequence = 0;
  const pending = new Map<
    number,
    {
      resolve: (options: FilterOption[]) => void;
      reject: (error: Error) => void;
    }
  >();
  function reset(request: Request | null) {
    pending.forEach((item) => item.resolve([]));
    pending.clear();
    current = request;
  }
  onMount(() => {
    let disposed = false;
    const stops: (() => void)[] = [];
    void (async () => {
      for (const subscription of [
        listen<Request | null>('filter-opened', ({ payload }) =>
          reset(payload),
        ),
        listen<{
          session: string;
          request: number;
          options: FilterOption[];
          error: string;
        }>('filter-results', ({ payload }) => {
          if (payload.session !== current?.session) return;
          const item = pending.get(payload.request);
          pending.delete(payload.request);
          if (payload.error) item?.reject(new Error(payload.error));
          else item?.resolve(payload.options);
        }),
      ]) {
        const stop = await subscription;
        if (disposed) stop();
        else stops.push(stop);
      }
      if (!disposed)
        reset(await invoke<Request | null>('filter_popup_request'));
    })().catch(console.error);
    return () => {
      disposed = true;
      stops.forEach((stop) => stop());
      reset(null);
    };
  });
  function loadOptions(query: string): Promise<FilterOption[]> {
    const request = ++sequence;
    return new Promise((resolve, reject) => {
      pending.set(request, { resolve, reject });
      void invoke('query_filter_popup', {
        session: current?.session,
        query,
        request,
      }).catch((error) => {
        pending.delete(request);
        reject(error);
      });
    });
  }
  function close(restore: boolean, value?: string) {
    if (current)
      void invoke('close_filter_popup', {
        session: current.session,
        restore,
        value,
      });
  }
</script>

<div bind:this={anchor}>
  <PopupWindow>
    {#if current}{#key current.session}
        <FilterPopupContent
          {...current}
          placement="anchor"
          {anchor}
          {loadOptions}
          onhighlight={(value) => {
            if (current)
              void invoke('highlight_filter_popup', {
                session: current.session,
                value,
              }).catch(console.error);
          }}
          onsize={(height) => {
            if (current)
              void invoke('size_filter_popup', {
                session: current.session,
                height,
              }).catch(console.error);
          }}
          onchoose={(value) => close(true, value)}
          onclose={(restore) => close(restore)}
        />
      {/key}{/if}
  </PopupWindow>
</div>

<svelte:window
  onkeydowncapture={(event) => {
    if ((event.metaKey || event.ctrlKey) && [',', 'k'].includes(event.key)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (current)
        void invoke('forward_filter_shortcut', {
          session: current.session,
          key: event.key,
          meta: event.metaKey,
          ctrl: event.ctrlKey,
        });
    } else if (event.key === 'Tab') {
      event.preventDefault();
      event.stopImmediatePropagation();
      close(true);
    }
  }}
/>
