<script lang="ts">
  import { ChevronDown } from '@lucide/svelte';
  import Keycap from './Keycap.svelte';
  import FilterPopup, { type FilterOption } from './FilterPopup.svelte';
  let {
    value = $bindable('all'),
    options,
    label = 'Filter results',
  }: { value: string; options: FilterOption[]; label?: string } = $props();
  const id = $props.id();
  let open = $state(false);
  let container = $state<HTMLDivElement>();
  let trigger: HTMLButtonElement;
  let selected = $derived(options.find((option) => option.value === value));
  function close(restore = false) {
    open = false;
    if (restore) trigger.focus();
  }
  function shortcut(event: KeyboardEvent) {
    if (
      (event.metaKey || event.ctrlKey) &&
      !event.shiftKey &&
      event.key.toLowerCase() === 'p' &&
      !event.isComposing
    ) {
      event.preventDefault();
      event.stopImmediatePropagation();
      open ? close(true) : (open = true);
    }
  }
</script>

<svelte:window onkeydown={shortcut} />
<div
  class="filter-control"
  bind:this={container}
  role="group"
  aria-label={label}
>
  <button
    class="filter-trigger"
    class:active={open}
    bind:this={trigger}
    aria-label={label}
    aria-haspopup="dialog"
    aria-expanded={open}
    aria-controls={id}
    onclick={() => (open ? close() : (open = true))}
    onkeydown={(event) => {
      if (event.isComposing) return;
      if (['ArrowDown', 'ArrowUp'].includes(event.key)) {
        event.preventDefault();
        event.stopPropagation();
        open = true;
      } else if (['Enter', ' '].includes(event.key)) event.stopPropagation();
    }}
  >
    <span>{selected?.label ?? 'All'}</span><ChevronDown size={14} />
    <span class="filter-shortcut" aria-hidden="true"
      ><Keycap text={/Mac/.test(navigator.platform) ? '⌘' : 'Ctrl'} /><Keycap
        text="P"
      /></span
    >
  </button>
  {#if open && container}<FilterPopup
      {id}
      anchor={container}
      {value}
      {label}
      loadOptions={(query) =>
        options.filter((option) =>
          option.label.toLowerCase().includes(query.toLowerCase()),
        )}
      onchoose={(next) => {
        value = next;
        close(true);
      }}
      onclose={close}
    />{/if}
</div>
