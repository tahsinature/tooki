<script lang="ts">
  import type { Arguments, Record } from './api';
  import TextInput from '../../components/TextInput.svelte';
  import ChoiceInput from './ChoiceInput.svelte';
  let {
    record,
    values = $bindable<Arguments>({}),
  }: { record: Record; values: Arguments } = $props();
  const uid = $props.id();
</script>

<div class="snippet-inputs">
  {#each record.definition.inputs as input (input.key)}
    <div class="snippet-input">
      <label for={`${uid}-${input.key}`}
        >{input.label}{input.required ? '' : ' (optional)'}</label
      >
      {#if input.kind === 'choice'}
        <ChoiceInput
          id={`${uid}-${input.key}`}
          label={input.label}
          choices={record.configuration.choices[input.key] ?? []}
          bind:value={
            () =>
              values[input.key] ??
              record.configuration.defaults[input.key] ??
              '',
            (value) => (values = { ...values, [input.key]: value ?? '' })
          }
        />
      {:else}
        <TextInput
          id={`${uid}-${input.key}`}
          class="text-field"
          type={input.kind === 'number' ? 'number' : 'text'}
          step="any"
          value={values[input.key] ??
            record.configuration.defaults[input.key] ??
            ''}
          oninput={(e) =>
            (values = { ...values, [input.key]: e.currentTarget.value })}
        />
      {/if}
    </div>
  {/each}
</div>
