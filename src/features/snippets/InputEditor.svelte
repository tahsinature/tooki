<script lang="ts">
  import type { Record } from './api';
  import TextInput from '../../components/TextInput.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Button from '../../components/Button.svelte';
  import ChoiceInput from './ChoiceInput.svelte';
  import ChoiceRows from './ChoiceRows.svelte';
  let { record = $bindable<Record>() }: { record: Record } = $props();
  function add() {
    let number = 1;
    while (record.definition.inputs.some((i) => i.key === `input${number}`))
      number++;
    const key = `input${number}`;
    record.definition.inputs.push({
      key,
      label: 'New input',
      kind: 'text',
      required: true,
    });
    record.configuration.defaults[key] = '';
  }
  function rename(index: number, key: string) {
    const previous = record.definition.inputs[index].key;
    if (key === previous || record.definition.inputs.some((i) => i.key === key))
      return;
    record.definition.inputs[index].key = key;
    record.configuration.defaults[key] =
      record.configuration.defaults[previous] ?? '';
    if (record.configuration.choices[previous])
      record.configuration.choices[key] =
        record.configuration.choices[previous];
    delete record.configuration.defaults[previous];
    delete record.configuration.choices[previous];
    record.definition.template = record.definition.template.replace(
      /\{\{([^{}]+)\}\}/g,
      (field, contents: string) => {
        const source = contents.split('|')[0].trim();
        return source === `input:${previous}` || source === `lookup:${previous}`
          ? field.replace(
              source,
              source.slice(0, source.indexOf(':') + 1) + key,
            )
          : field;
      },
    );
  }
</script>

<div class="snippet-section-heading">
  <h3>Inputs</h3>
  <Button onclick={add}>Add Input</Button>
</div>
<p class="snippet-hint">
  Tooki asks for these when you run the snippet. Insert them into your content
  with Insert Field.
</p>
{#each record.definition.inputs as input, index}
  <div class="snippet-input-editor">
    <div class="snippet-field-grid">
      <label
        >Label<TextInput class="text-field" bind:value={input.label} /></label
      >
      <label
        >Key<TextInput
          class="text-field"
          value={input.key}
          onchange={(event) => rename(index, event.currentTarget.value.trim())}
        /></label
      >
      <label
        >Type<ChoiceInput
          id={`snippet-type-${index}`}
          label="Input type"
          choices={['text', 'number', 'choice'].map((key) => ({
            key,
            label: key[0].toUpperCase() + key.slice(1),
            value: key,
          }))}
          bind:value={input.kind}
        /></label
      >
      <label
        >Default (optional)<TextInput
          class="text-field"
          bind:value={record.configuration.defaults[input.key]}
          placeholder={input.kind === 'choice' ? 'Choice key' : 'Ask each time'}
        /></label
      >
    </div>
    {#if input.kind === 'choice'}<ChoiceRows
        bind:rows={record.configuration.choices[input.key]}
      />{/if}
    <div class="snippet-section-heading">
      <span class="snippet-required"
        >Required <Toggle
          label={`${input.label} is required`}
          checked={input.required}
          onchange={(value) => (input.required = value)}
        /></span
      ><Button
        destructive
        onclick={() => {
          record.definition.inputs.splice(index, 1);
          delete record.configuration.defaults[input.key];
          delete record.configuration.choices[input.key];
        }}>Remove Input</Button
      >
    </div>
  </div>
{/each}
