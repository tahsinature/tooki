<script lang="ts">
  import type { Record } from './api';
  import FilterPopup from '../../components/FilterPopup.svelte';
  let { record = $bindable<Record>() }: { record: Record } = $props();
  let fieldOpen = $state(false);
  let fieldAnchor = $state<HTMLButtonElement>();
  let textarea = $state<HTMLTextAreaElement>();
  let start = 0,
    end = 0;
  let fields = $derived([
    { value: '{{date}}', label: 'Current Date · 2026-11-17' },
    { value: '{{date:short}}', label: 'Current Date · 17/11/2026' },
    { value: '{{date:long}}', label: 'Current Date · November 17, 2026' },
    { value: '{{time}}', label: 'Current Time · 24 hour' },
    { value: '{{time:12h}}', label: 'Current Time · 12 hour' },
    ...record.definition.inputs.map((i) => ({
      value: `{{${i.kind === 'choice' ? 'lookup' : 'input'}:${i.key}}}`,
      label: i.label,
    })),
    ...Object.keys(record.configuration.values).map((key) => ({
      value: `{{value:${key}}}`,
      label: `Saved value · ${key}`,
    })),
  ]);
  function insert(value: string) {
    const text = record.definition.template;
    record.definition.template = text.slice(0, start) + value + text.slice(end);
    fieldOpen = false;
    textarea?.focus();
  }
</script>

<div class="snippet-section-heading">
  <label for="snippet-content">Content</label><button
    class="control-button"
    bind:this={fieldAnchor}
    aria-haspopup="dialog"
    aria-expanded={fieldOpen}
    onclick={() => {
      start = textarea?.selectionStart ?? record.definition.template.length;
      end = textarea?.selectionEnd ?? start;
      fieldOpen = !fieldOpen;
    }}>Insert Field</button
  >
</div>
<textarea
  id="snippet-content"
  class="text-field snippet-template"
  bind:this={textarea}
  bind:value={record.definition.template}
  rows="6"
  spellcheck="false"
  placeholder="Write your snippet, then insert dynamic fields where needed."
></textarea>
{#if fieldOpen && fieldAnchor}<FilterPopup
    id="snippet-insert-field"
    anchor={fieldAnchor}
    value=""
    label="Insert Field"
    loadOptions={(query) =>
      fields.filter((field) =>
        field.label.toLowerCase().includes(query.toLowerCase()),
      )}
    onchoose={insert}
    onclose={() => (fieldOpen = false)}
  />{/if}
<p class="snippet-hint">
  Fields are resolved when the snippet runs. Example: <code
    >{'Hi {{input:name}}, today is {{date}}.'}</code
  >
</p>
