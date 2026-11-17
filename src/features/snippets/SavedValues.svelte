<script lang="ts">
  import TextInput from '../../components/TextInput.svelte';
  import Button from '../../components/Button.svelte';
  let {
    values = $bindable<{ [key: string]: string }>({}),
  }: { values: { [key: string]: string } } = $props();
  function add() {
    let index = 1;
    while (`value${index}` in values) index++;
    values[`value${index}`] = '';
  }
  function rename(previous: string, key: string) {
    if (key === previous || key in values || !key) return;
    const copy = { ...values };
    copy[key] = copy[previous];
    delete copy[previous];
    values = copy;
  }
</script>

<details class="snippet-advanced">
  <summary>Saved values & formatting</summary>
  <p class="snippet-hint">
    Keep personal details here and insert them as fields. These values stay
    separate from the reusable definition.
  </p>
  {#each Object.entries(values) as [key, value] (key)}
    <div class="snippet-value-row">
      <TextInput
        class="text-field"
        aria-label="Saved value key"
        value={key}
        onchange={(e) => rename(key, e.currentTarget.value.trim())}
      /><TextInput
        class="text-field"
        aria-label={`Value for ${key}`}
        {value}
        oninput={(e) => (values[key] = e.currentTarget.value)}
      /><button
        class="icon-button"
        aria-label={`Remove ${key}`}
        onclick={() => {
          const copy = { ...values };
          delete copy[key];
          values = copy;
        }}>×</button
      >
    </div>
  {/each}
  <Button onclick={add}>Add Saved Value</Button>
  <p class="snippet-hint">
    Format fields with <code>| trim</code>, <code>| upper</code>,
    <code>| lower</code>
    or <code>| default:Guest</code>. Example:
    <code>{'{{input:name | trim | upper}}'}</code>. Values are plain text, never
    executable code.
  </p>
</details>
