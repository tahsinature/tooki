<script lang="ts">
  import { onMount } from 'svelte';
  import TextInput from './TextInput.svelte';
  let {
    value,
    label,
    maxlength,
    oncommit,
    oncancel,
  }: {
    value: string;
    label: string;
    maxlength?: number;
    oncommit: (value: string) => void;
    oncancel: () => void;
  } = $props();
  // A rename is a transaction: Escape never saves a partial name.
  let draft = $state('');
  let input = $state<HTMLInputElement>(null!);
  let finished = false;
  onMount(() => {
    draft = value;
    input.focus();
    // Select after the bound value has reached the DOM.
    queueMicrotask(() => input.select());
  });
  function finish(commit: boolean) {
    if (finished) return;
    finished = true;
    if (commit) oncommit(draft);
    else oncancel();
  }
  function keyboard(event: KeyboardEvent) {
    event.stopPropagation();
    if (event.isComposing) return;
    if (event.key === 'Enter' || event.key === 'Escape') {
      event.preventDefault();
      finish(event.key === 'Enter');
    }
  }
</script>

<svelte:window
  onblur={() => finish(true)}
  onpointerdown={(event) => {
    if (event.target !== input) finish(true);
  }}
/>
<TextInput
  class="rename-input"
  aria-label={label}
  {maxlength}
  bind:element={input}
  bind:value={draft}
  onkeydown={keyboard}
  onblur={() => finish(true)}
  autocomplete="off"
  spellcheck="false"
/>
