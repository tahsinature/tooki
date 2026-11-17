<script lang="ts">
  import { request, type Record } from './api';
  import TextInput from '../../components/TextInput.svelte';
  import Button from '../../components/Button.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import TemplateEditor from './TemplateEditor.svelte';
  import InputEditor from './InputEditor.svelte';
  import ChoiceRows from './ChoiceRows.svelte';
  import SavedValues from './SavedValues.svelte';
  import SnippetPreview from './SnippetPreview.svelte';
  let {
    record = $bindable<Record>(),
    onsaved,
    oncancel,
  }: { record: Record; onsaved: () => void; oncancel: () => void } = $props();
  let busy = $state(false),
    error = $state('');
  async function save() {
    if (busy) return;
    busy = true;
    error = '';
    try {
      record = await request<Record>('save', record);
      onsaved();
    } catch (reason) {
      error = String(reason);
    } finally {
      busy = false;
    }
  }
  function keyboard(event: KeyboardEvent) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') {
      event.preventDefault();
      void save();
    }
  }
</script>

<svelte:window onkeydown={keyboard} />
<div class="snippet-editor">
  <div class="snippet-section-heading">
    <div>
      <h2>{record.revision ? 'Edit Snippet' : 'New Snippet'}</h2>
      <p class="snippet-hint">
        {record.definition.kind === 'choice'
          ? 'One trigger, several useful answers.'
          : record.definition.kind === 'template'
            ? 'Combine text with fields and inputs.'
            : 'Write once. Expand wherever you type.'}
      </p>
    </div>
    <Button onclick={oncancel}>Back to Library</Button>
  </div>
  <div class="snippet-field-grid">
    <label
      >Name<TextInput
        class="text-field"
        bind:value={record.definition.name}
        placeholder="e.g. Personal email"
        autofocus
      /></label
    >
    <label
      >Trigger<TextInput
        class="text-field"
        bind:value={record.configuration.trigger}
        placeholder="e.g. @email or $today"
        spellcheck="false"
      /></label
    >
  </div>
  {#if record.definition.kind === 'choice'}
    <div class="snippet-section-heading"><h3>Choices</h3></div>
    <ChoiceRows
      bind:rows={record.configuration.choices[record.definition.inputs[0].key]}
    />
    <p class="snippet-hint">
      Type <code>{record.configuration.trigger || '@email'}-1</code> then Space
      for the first result. Use
      <code>{record.configuration.trigger || '@email'}</code> then Space to choose.
    </p>
  {:else}
    <TemplateEditor bind:record />
    {#if record.definition.kind === 'template'}<InputEditor bind:record />{/if}
  {/if}
  <SavedValues bind:values={record.configuration.values} />
  <details class="snippet-advanced">
    <summary>Organization & expansion</summary>
    <div class="snippet-field-grid">
      <label
        >Collection<TextInput
          class="text-field"
          bind:value={record.definition.collection}
          placeholder="e.g. Work"
        /></label
      ><label
        >Description<TextInput
          class="text-field"
          bind:value={record.definition.description}
          placeholder="A short reminder"
        /></label
      >
    </div>
    <SettingsRow
      title="Enabled"
      description="Available in the launcher and for expansion."
      ><Toggle
        label="Snippet enabled"
        checked={record.configuration.enabled}
        onchange={(value) => (record.configuration.enabled = value)}
      /></SettingsRow
    >
    <SettingsRow
      title="Expand while typing"
      description="Requires automatic expansion to be enabled in Snippets settings."
      ><Toggle
        label="Expand this snippet while typing"
        checked={record.configuration.automatic}
        onchange={(value) => (record.configuration.automatic = value)}
      /></SettingsRow
    >
    <SettingsRow
      title="Expand instantly"
      description="Off by default. Press Space to finish the trigger and keep the space."
      ><Toggle
        label="Expand instantly"
        disabled={record.definition.kind === 'choice'}
        checked={record.configuration.instant}
        onchange={(value) => (record.configuration.instant = value)}
      /></SettingsRow
    >
  </details>
  <SnippetPreview {record} />
  {#if error}<p class="error-message" role="alert">{error}</p>{/if}
  <div class="snippet-editor-actions">
    <Button onclick={oncancel} disabled={busy}>Cancel</Button><Button
      onclick={() => void save()}
      disabled={busy}>{busy ? 'Saving…' : 'Save Snippet'}</Button
    >
  </div>
</div>
