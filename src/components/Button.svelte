<script lang="ts">
  import type { Snippet } from 'svelte';
  let {
    children,
    onclick,
    type = 'button',
    disabled = false,
    destructive = false,
    dialogAutofocus = false,
    label,
  }: {
    children: Snippet;
    type?: 'button' | 'submit' | 'reset';
    onclick?: () => void;
    disabled?: boolean;
    destructive?: boolean;
    dialogAutofocus?: boolean;
    label?: string;
  } = $props();
</script>

<button
  {type}
  class="control-button"
  class:destructive
  {onclick}
  {disabled}
  data-dialog-autofocus={dialogAutofocus || undefined}
  aria-label={label}>{@render children()}</button
>
