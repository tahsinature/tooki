<script lang="ts" module>
  export type FilterOption = { value: string; label: string };
</script>

<script lang="ts">
  import TextInput from './TextInput.svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { flip } from 'svelte/animate';
  import { fade } from 'svelte/transition';
  import './filter-popup.css';
  let {
    id,
    anchor,
    placement = 'anchor',
    value,
    label,
    placeholder = 'Type to filter…',
    emptyMessage = 'No matching options',
    loadOptions,
    onchoose,
    onhighlight,
    onclose,
    onsize,
  }: {
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
    onsize?: (height: number) => void;
  } = $props();
  let popupTop = $state(0);
  let query = $state('');
  let options = $state<FilterOption[]>([]);
  let highlighted = $state(0);
  let loading = $state(true);
  let error = $state('');
  let input = $state<HTMLInputElement>(null!);
  let surface: HTMLDivElement;
  let list: HTMLDivElement;
  let reducedMotion = $state(false);
  onMount(() => {
    popupTop = anchor.getBoundingClientRect().bottom + 6;
    input.focus();
    const preference = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => (reducedMotion = preference.matches);
    update();
    preference.addEventListener('change', update);
    return () => preference.removeEventListener('change', update);
  });
  $effect(() => {
    const search = query;
    const selectedValue = value;
    let cancelled = false;
    loading = true;
    error = '';
    void (async () => {
      try {
        const result = await loadOptions(search);
        if (cancelled) return;
        const previous = untrack(() => options[highlighted]?.value);
        const retained = result.findIndex(
          (option) => option.value === previous,
        );
        options = result;
        highlighted =
          retained >= 0
            ? retained
            : search
              ? 0
              : Math.max(
                  0,
                  result.findIndex((option) => option.value === selectedValue),
                );
        await reveal();
      } catch (e) {
        if (!cancelled) {
          error = String(e);
          options = [];
          highlighted = 0;
        }
      } finally {
        if (!cancelled) loading = false;
      }
    })();
    return () => {
      cancelled = true;
    };
  });
  $effect(() => {
    options;
    loading;
    error;
    if (!onsize || loading) return;
    let cancelled = false;
    void tick().then(() => {
      if (cancelled || !surface || !list || !input) return;
      const style = getComputedStyle(surface);
      const search = getComputedStyle(input);
      const rowsHeight = Array.from(list.children).reduce((height, child) => {
        const optionValue = (child as HTMLElement).dataset.value;
        if (
          optionValue !== undefined &&
          !options.some((option) => option.value === optionValue)
        )
          return height;
        const row = getComputedStyle(child);
        return (
          height +
          child.getBoundingClientRect().height +
          parseFloat(row.marginTop) +
          parseFloat(row.marginBottom)
        );
      }, 0);
      const height =
        input.getBoundingClientRect().height +
        parseFloat(search.marginBottom) +
        rowsHeight +
        parseFloat(style.paddingTop) +
        parseFloat(style.paddingBottom) +
        parseFloat(style.borderTopWidth) +
        parseFloat(style.borderBottomWidth);
      onsize?.(Math.min(250, Math.ceil(height)) + 2);
    });
    return () => {
      cancelled = true;
    };
  });
  $effect(() => {
    if (!loading) onhighlight?.(options[highlighted]?.value ?? null);
  });
  async function reveal() {
    await tick();
    list
      ?.querySelector(`[data-option="${highlighted}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  }
  function outside(target: EventTarget | null) {
    return (
      target instanceof Node &&
      !surface?.contains(target) &&
      !anchor.contains(target)
    );
  }
  function keyboard(event: KeyboardEvent) {
    if (event.isComposing) {
      event.stopPropagation();
      return;
    }
    const modifier = event.metaKey || event.ctrlKey;
    if (modifier && !event.shiftKey && event.key.toLowerCase() === 'p') {
      event.preventDefault();
      event.stopImmediatePropagation();
      onclose(true);
      return;
    }
    if (modifier && ['Escape', ',', 'k'].includes(event.key)) {
      onclose(false);
      return;
    }
    event.stopPropagation();
    if (event.key === 'Escape') {
      event.preventDefault();
      onclose(true);
    } else if (event.key === 'Tab') onclose(false);
    else if (event.key === 'Enter') {
      event.preventDefault();
      if (!loading && options[highlighted])
        onchoose(options[highlighted].value);
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      if (options.length) {
        highlighted =
          (highlighted +
            (event.key === 'ArrowDown' ? 1 : -1) +
            options.length) %
          options.length;
        void reveal();
      }
    }
  }
</script>

<svelte:window
  onpointerdown={(event) => {
    if (outside(event.target)) onclose(false);
  }}
  onfocusin={(event) => {
    if (outside(event.target)) onclose(false);
  }}
/>
<div
  class="popup filter-popup"
  style:position={placement === 'window' ? 'fixed' : undefined}
  style:left={placement === 'window' ? '16px' : undefined}
  style:right={placement === 'window' ? '16px' : undefined}
  style:top={placement === 'window' ? `${popupTop}px` : undefined}
  style:width={placement === 'window' ? 'auto' : undefined}
  bind:this={surface}
  {id}
  role="dialog"
  tabindex="-1"
  aria-label={label}
  onkeydown={keyboard}
>
  <TextInput
    data-search-input
    class="filter-search"
    bind:element={input}
    bind:value={query}
    {placeholder}
    aria-label={`Search ${label.toLowerCase()}`}
    role="combobox"
    aria-expanded="true"
    aria-controls={`${id}-options`}
    aria-activedescendant={options[highlighted]
      ? `${id}-option-${highlighted}`
      : undefined}
    autocomplete="off"
  />
  <div
    class="filter-options"
    bind:this={list}
    role="listbox"
    id={`${id}-options`}
    aria-label={label}
    aria-busy={loading}
  >
    {#each options as option, index (option.value)}
      <button
        animate:flip={{ duration: reducedMotion ? 0 : 140 }}
        in:fade={{ duration: reducedMotion ? 0 : 140 }}
        out:fade={{ duration: reducedMotion ? 0 : 100 }}
        onintrostart={(event) => {
          const row = event.currentTarget;
          delete row.dataset.leaving;
          row.disabled = false;
          row.id = `${id}-option-${index}`;
          row.removeAttribute('aria-hidden');
        }}
        onoutrostart={(event) => {
          const row = event.currentTarget;
          row.dataset.leaving = 'true';
          row.disabled = true;
          row.removeAttribute('id');
          row.setAttribute('aria-hidden', 'true');
        }}
        class:highlighted={highlighted === index}
        role="option"
        aria-selected={value === option.value}
        id={`${id}-option-${index}`}
        data-option={index}
        data-value={option.value}
        tabindex="-1"
        onpointermove={() => (highlighted = index)}
        onmousedown={(event) => event.preventDefault()}
        onclick={() => onchoose(option.value)}
      >
        <span class="filter-option-label" title={option.label}
          >{option.label}</span
        >
      </button>
    {:else}<p class="filter-empty" role={error ? 'alert' : 'status'}>
        {error || (loading ? 'Loading…' : emptyMessage)}
      </p>{/each}
  </div>
</div>
