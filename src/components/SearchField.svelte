<script lang="ts">
  import { Search, X } from '@lucide/svelte';
  import TextInput from './TextInput.svelte';
  let {
    value = $bindable(''),
    label,
    placeholder = 'Search…',
    element = $bindable(),
  }: {
    value?: string;
    label: string;
    placeholder?: string;
    element?: HTMLInputElement;
  } = $props();
  function clear() {
    value = '';
    element?.focus();
  }
</script>

<div class="search-field input-frame">
  <Search size={15} aria-hidden="true" />
  <TextInput
    data-search-input
    bind:value
    bind:element
    aria-label={label}
    {placeholder}
    autocomplete="off"
    spellcheck={false}
  />
  {#if value}<button
      class="clear-search"
      type="button"
      aria-label={`Clear ${label.toLowerCase()}`}
      title="Clear search"
      onclick={clear}><X size={13} aria-hidden="true" /></button
    >
  {/if}
</div>

<style>
  .search-field {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    min-width: 0;
    min-height: 34px;
    padding: 5px 8px 5px 10px;
    border: 1px solid var(--line);
    border-radius: var(--radius-control);
    background: var(--hover);
    color: var(--muted);
  }
  .search-field > :global(svg) {
    flex: none;
  }
  .search-field :global(input) {
    flex: 1;
    width: 100%;
    color: var(--ink);
    font-size: var(--font-size, 14px);
    line-height: 1.4;
  }
  .clear-search {
    display: grid;
    place-items: center;
    flex: none;
    width: 22px;
    height: 22px;
    padding: 0;
    border: 0;
    border-radius: var(--radius-control);
    background: transparent;
    color: var(--muted);
    cursor: pointer;
  }
  .clear-search:hover {
    background: var(--selected);
    color: var(--ink);
  }
  .clear-search:focus-visible {
    outline: 1px solid var(--input-focus-border);
    outline-offset: 1px;
  }
</style>
