<script lang="ts">
  import FilterPopup from '../../components/FilterPopup.svelte';
  import type { Choice } from './api';
  let {
    id,
    label,
    choices,
    value = $bindable<string>(),
  }: { id: string; label: string; choices: Choice[]; value: string } = $props();
  let open = $state(false);
  let anchor = $state<HTMLButtonElement>();
</script>

<button
  {id}
  class="control-button snippet-choice-button"
  bind:this={anchor}
  aria-label={label}
  aria-haspopup="dialog"
  aria-expanded={open}
  onclick={() => (open = !open)}
>
  {choices.find((choice) => choice.key === value)?.label ??
    `Choose ${label.toLowerCase()}…`} <span aria-hidden="true">⌄</span>
</button>
{#if open && anchor}
  <FilterPopup
    {id}
    {anchor}
    value={value ?? ''}
    {label}
    loadOptions={(query) =>
      choices
        .filter((c) =>
          `${c.label} ${c.key}`.toLowerCase().includes(query.toLowerCase()),
        )
        .map((c) => ({ value: c.key, label: c.label, detail: c.key }))}
    onchoose={(next) => {
      value = next;
      open = false;
      anchor?.focus();
    }}
    onclose={(restoreFocus) => {
      open = false;
      if (restoreFocus) anchor?.focus();
    }}
  />
{/if}
