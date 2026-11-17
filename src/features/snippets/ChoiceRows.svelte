<script lang="ts">
  import type { Choice } from './api';
  import TextInput from '../../components/TextInput.svelte';
  import Button from '../../components/Button.svelte';
  let { rows = $bindable<Choice[]>() }: { rows?: Choice[] } = $props();
  function addChoice() {
    let number = 1;
    while (rows?.some((choice) => choice.key === String(number))) number++;
    rows = [...(rows ?? []), { key: String(number), label: '', value: '' }];
  }
</script>

<div class="snippet-choice-table">
  <div class="snippet-choice-head">
    <span>Key</span><span>Label</span><span>Result</span><span></span>
  </div>
  {#each rows ?? [] as choice, i}
    <div class="snippet-choice-row">
      <TextInput
        class="text-field"
        aria-label={`Choice ${i + 1} key`}
        bind:value={choice.key}
        placeholder="1"
      />
      <TextInput
        class="text-field"
        aria-label={`Choice ${i + 1} label`}
        bind:value={choice.label}
        placeholder="Personal"
      />
      <TextInput
        class="text-field"
        aria-label={`Choice ${i + 1} result`}
        bind:value={choice.value}
        placeholder="What to insert"
      />
      <button
        class="icon-button"
        aria-label={`Remove choice ${i + 1}`}
        onclick={() => (rows = (rows ?? []).filter((_, index) => index !== i))}
        >×</button
      >
    </div>
  {/each}
  <Button onclick={addChoice}>Add Choice</Button>
</div>
