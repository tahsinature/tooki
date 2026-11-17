<script lang="ts">
  import { request, type Record, type Arguments, type Evaluation } from './api';
  import SnippetInputs from './SnippetInputs.svelte';
  let {
    record,
    saved = false,
    refresh = 0,
    values = $bindable<Arguments>({}),
    result = $bindable<Evaluation | null>(null),
    error = $bindable(''),
    busy = $bindable(false),
  }: {
    record: Record;
    saved?: boolean;
    refresh?: number;
    values?: Arguments;
    result?: Evaluation | null;
    error?: string;
    busy?: boolean;
  } = $props();
  let generation = 0;
  $effect(() => {
    refresh;
    const snapshot = JSON.parse(JSON.stringify(record));
    const arguments_ = { ...values };
    const token = ++generation;
    result = null;
    error = '';
    busy = true;
    const timer = setTimeout(() => {
      void request<Evaluation>(
        saved ? 'prepare' : 'preview',
        saved
          ? { id: snapshot.definition.id, arguments: arguments_ }
          : { record: snapshot, arguments: arguments_ },
      )
        .then((next) => {
          if (token === generation) result = next;
        })
        .catch((reason) => {
          if (token === generation) error = String(reason);
        })
        .finally(() => {
          if (token === generation) busy = false;
        });
    }, 120);
    return () => {
      clearTimeout(timer);
      generation++;
    };
  });
</script>

<div class="snippet-preview">
  <SnippetInputs {record} bind:values />
  <div class="snippet-preview-heading">
    <h3>{saved ? 'Result' : 'Try it'}</h3>
    <span>{busy ? 'Preparing…' : 'Local evaluation'}</span>
  </div>
  {#if error}<p class="error-message" role="alert">{error}</p>
  {:else if result?.text != null}<pre
      class="snippet-output"
      aria-label="Snippet result">{result.text || '(Empty result)'}</pre>
  {:else}<p class="snippet-hint">
      {record.definition.inputs.length
        ? 'Fill in the inputs to see the result.'
        : 'Write some content to preview your snippet.'}
    </p>{/if}
</div>
