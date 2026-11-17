<script lang="ts">
  import { ChevronDown } from '@lucide/svelte';
  import type { Component } from 'svelte';
  import FilterPopup from '../FilterPopup.svelte';
  let {
    label,
    icon: Icon,
    actions,
  }: {
    label: string;
    icon: Component<{ size?: number }>;
    actions: { label: string; run: () => void }[];
  } = $props();
  const id = $props.id();
  let trigger = $state<HTMLButtonElement>();
  let opened = $state(false);
  function close(restore = false) {
    opened = false;
    if (restore) trigger?.focus({ preventScroll: true });
  }
</script>

<button
  class="control-button"
  bind:this={trigger}
  aria-haspopup="dialog"
  aria-expanded={opened}
  aria-controls={id}
  onclick={() => (opened = !opened)}
  onkeydown={(event) => {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      opened = true;
    }
  }}><Icon size={14} />{label}<ChevronDown size={12} /></button
>
{#if opened && trigger}
  <FilterPopup
    {id}
    anchor={trigger}
    value=""
    {label}
    loadOptions={(query) =>
      actions
        .map((action, index) => ({ value: String(index), label: action.label }))
        .filter((option) =>
          option.label.toLowerCase().includes(query.toLowerCase()),
        )}
    onchoose={(value) => {
      close(true);
      actions[Number(value)]?.run();
    }}
    onclose={close}
  />
{/if}
