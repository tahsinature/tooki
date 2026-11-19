<script lang="ts">
  import TextInput from './TextInput.svelte';
  import { onMount, tick, type Component } from 'svelte';
  import Keycap from './Keycap.svelte';
  let {
    actions,
  }: {
    actions: {
      id: string;
      label: string;
      icon: Component<{ size?: number }>;
      run: () => void;
      shortcut?: string;
      disabled?: boolean;
      destructive?: boolean;
    }[];
  } = $props();
  const id = $props.id();
  let query = $state('');
  let selected = $state(0);
  let input = $state<HTMLInputElement>(null!);
  let list: HTMLDivElement;
  let filtered = $derived(
    actions.filter((action) =>
      query
        .toLowerCase()
        .trim()
        .split(/\s+/)
        .every((term) => action.label.toLowerCase().includes(term)),
    ),
  );
  $effect(() => {
    filtered;
    selected = Math.max(
      0,
      filtered.findIndex((action) => !action.disabled),
    );
    list?.scrollTo({ top: 0 });
  });
  onMount(() => input.focus());
  async function keyboard(event: KeyboardEvent) {
    if (event.isComposing) return;
    if (['ArrowDown', 'ArrowUp', 'Tab', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      event.stopPropagation();
      const enabled = filtered
        .map((action, index) => (action.disabled ? -1 : index))
        .filter((index) => index >= 0);
      if (!enabled.length) return;
      const current = enabled.indexOf(selected);
      const step =
        event.key === 'ArrowUp' || (event.key === 'Tab' && event.shiftKey)
          ? -1
          : 1;
      selected =
        event.key === 'Home'
          ? enabled[0]
          : event.key === 'End'
            ? enabled.at(-1)!
            : enabled[(current + step + enabled.length) % enabled.length];
      await tick();
      list
        .querySelector(`[data-action-index="${selected}"]`)
        ?.scrollIntoView({ block: 'nearest' });
    } else if (event.key === 'Enter') {
      event.preventDefault();
      event.stopPropagation();
      // Holding Enter must not activate a newly opened confirmation step.
      if (event.repeat) return;
      const action = filtered[selected];
      if (action && !action.disabled) action.run();
    }
  }
</script>

<div
  class="actions-list"
  bind:this={list}
  id={`${id}-list`}
  role="listbox"
  aria-label="Actions"
>
  {#each filtered as action, index (action.id)}
    <button
      id={`${id}-${index}`}
      data-action-index={index}
      role="option"
      aria-selected={selected === index}
      class:destructive={action.destructive}
      class:selected={selected === index && !action.disabled}
      tabindex="-1"
      disabled={action.disabled}
      onpointermove={() => {
        if (!action.disabled) selected = index;
      }}
      onmousedown={(event) => event.preventDefault()}
      onclick={action.run}
    >
      <action.icon size={15} /><span class="action-label">{action.label}</span>
      {#if action.shortcut}<Keycap text={action.shortcut} />{/if}
    </button>
  {:else}<p class="actions-empty">No matching actions</p>{/each}
</div>
<TextInput
  data-search-input
  bind:element={input}
  class="actions-search"
  placeholder="Search for actions…"
  aria-label="Search for actions"
  role="combobox"
  aria-expanded="true"
  aria-controls={`${id}-list`}
  aria-activedescendant={filtered[selected] ? `${id}-${selected}` : undefined}
  bind:value={query}
  onkeydown={keyboard}
  autocomplete="off"
/>
