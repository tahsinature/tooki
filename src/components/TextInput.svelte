<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements';
  import './text-input.css';
  let {
    value = $bindable(''),
    element = $bindable(),
    class: className = '',
    ...attributes
  }: HTMLInputAttributes & { element?: HTMLInputElement } = $props();
</script>

<input
  {...attributes}
  class={['text-input', className]}
  bind:this={element}
  bind:value
/>
