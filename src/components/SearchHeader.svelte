<script lang="ts">
  import TextInput from './TextInput.svelte';
  import { launcherDrag } from '../features/launcher/placement.svelte';
  import PanelFilterMenu from './PanelFilterMenu.svelte';
  import { Command, ArrowLeft } from '@lucide/svelte';
  let input = $state<HTMLInputElement>();
  let {
    query = $bindable(''),
    filter = $bindable('all'),
    clipboard,
    onback,
    placeholder,
    filterOptions,
  }: {
    placeholder?: string;
    filterOptions?: { value: string; label: string }[];
    query: string;
    filter: string;
    clipboard: boolean;
    onback?: () => void;
  } = $props();
</script>

<header class="search-header" use:launcherDrag>
  {#if clipboard && onback}<button
      class="icon-button back"
      aria-label="Back to root search"
      onclick={onback}><ArrowLeft size={20} /></button
    >{:else}<Command size={19} class="muted" />{/if}
  <TextInput
    data-search-input
    id="search"
    aria-label={placeholder ??
      (clipboard ? 'Search clipboard' : 'Search commands')}
    placeholder={placeholder ??
      (clipboard ? 'Search clipboard…' : 'Search or type a command…')}
    bind:value={query}
    bind:element={input}
    autocomplete="off"
    spellcheck="false"
  />
  {#if filterOptions ? filterOptions.length > 0 : clipboard}<PanelFilterMenu
      bind:value={filter}
      onapply={() => input?.focus({ preventScroll: true })}
      options={filterOptions ??
        (clipboard
          ? [
              { value: 'all', label: 'All Types' },
              { value: 'text', label: 'Text' },
              { value: 'link', label: 'Links' },
              { value: 'image', label: 'Images' },
              { value: 'file', label: 'Files' },
              { value: 'color', label: 'Colors' },
              { value: 'dropped', label: 'Dropped' },
              { value: 'unavailable', label: 'Unavailable' },
              { value: 'pinned', label: 'Pinned' },
            ]
          : [{ value: 'all', label: 'All' }])}
    />{/if}
</header>
