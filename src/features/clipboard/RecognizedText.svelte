<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { request } from './api';
  import EmptyState from '../../components/EmptyState.svelte';

  let {
    id,
    revision,
    onshowimage,
  }: {
    id: string;
    revision: number;
    onshowimage: () => void;
  } = $props();
  let text = $state('');
  let loading = $state(true);
  let error = $state('');
  let container: HTMLDivElement;
  let textarea = $state<HTMLTextAreaElement>();
  // A refreshed clipboard record must not restart recognition or discard selection.
  const selectedId = $derived(id);
  const retry = $derived(revision);
  onMount(() => container.focus());

  $effect(() => {
    let cancelled = false;
    loading = true;
    error = '';
    void request<string>('recognizeText', { id: selectedId, force: retry > 0 })
      .then(async (result) => {
        if (cancelled) return;
        text = result;
        loading = false;
        await tick();
        if (!cancelled && document.activeElement === container)
          textarea?.focus();
      })
      .catch((reason) => {
        if (!cancelled) {
          error = String(reason);
          loading = false;
        }
      });
    return () => {
      cancelled = true;
    };
  });
</script>

<div class="clipboard-recognized-text" bind:this={container} tabindex="-1">
  <div class="clipboard-text-heading">
    <strong>Recognized Text</strong>
    <button class="control-button" onclick={onshowimage}>Show Image</button>
  </div>
  {#if loading}
    <p class="muted" role="status">Recognizing text…</p>
  {:else if error}
    <p role="alert">{error}</p>
    <p class="muted">Try Recognize Text Again in Actions.</p>
  {:else if !text.trim()}
    <EmptyState
      title="No text found"
      description="No text could be recognized in this image."
    />
  {:else}
    <p class="muted">Select any text and press ⌘C to copy.</p>
    <textarea
      bind:this={textarea}
      class="document-preview"
      aria-label="Recognized text"
      readonly
      value={text}></textarea>
  {/if}
</div>

<style>
  .clipboard-recognized-text {
    display: flex;
    flex: 1;
    flex-direction: column;
    height: 100%;
    min-height: 200px;
    gap: 12px;
  }
  .clipboard-text-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  p {
    margin: 0;
  }
  textarea {
    flex: 1;
    width: 100%;
    resize: none;
    font: inherit;
    line-height: 1.6;
  }
</style>
