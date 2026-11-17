<script lang="ts">
  import { request, type Clip } from './api';
  import DetailLayout from '../../components/DetailLayout.svelte';
  import InformationList from '../../components/InformationList.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  let { id, revision = 0 }: { id?: string; revision?: number } = $props();
  let clip = $state<Clip>();
  let image = $state('');
  let error = $state('');
  $effect(() => {
    const selected = id;
    revision;
    let cancelled = false;
    clip = undefined;
    image = '';
    error = '';
    if (selected)
      void request<Clip>('detail', { id: selected })
        .then(async (value) => {
          if (cancelled) return;
          clip = value;
          if (value.image) {
            const data = await request<string>('image', { id: selected });
            if (!cancelled) image = data;
          }
        })
        .catch((e) => {
          if (!cancelled) error = String(e);
        });
    return () => {
      cancelled = true;
    };
  });
</script>

<DetailLayout label="Clipboard preview">
  {#if error}<p role="alert">{error}</p>
  {:else if clip}
    {#if clip.kind === 'image'}
      {#if image}<img
          class="clipboard-image"
          src={image}
          alt={clip.title}
        />{:else}<p class="muted">Loading image…</p>{/if}
    {:else if clip.kind === 'file'}
      <div class="document-preview"><pre>{clip.files.join('\n')}</pre></div>
    {:else}
      {#if clip.kind === 'color'}<div
          class="clipboard-color"
          style:background={clip.content.trim()}
        ></div>{/if}
      <div class="document-preview"><pre>{clip.content}</pre></div>
    {/if}
    {#if clip.missingFiles.length > 0}<p role="status">
        An original file has moved or been deleted.
      </p>{/if}
  {:else}<EmptyState
      title={id ? 'Loading preview…' : 'No clip selected'}
      description={id ? '' : 'Copy something to get started.'}
    />{/if}
  {#snippet information()}
    {#if clip}
      <InformationList
        entries={[
          { label: 'Type', value: clip.kind },
          ...(clip.kind === 'image'
            ? [
                {
                  label: 'Dimensions',
                  value: `${clip.width} × ${clip.height} px`,
                },
              ]
            : []),
          {
            label: 'Size',
            value:
              clip.bytes >= 1048576
                ? `${(clip.bytes / 1048576).toFixed(1)} MB`
                : `${Math.ceil(clip.bytes / 1024)} KB`,
          },
          { label: 'Source', value: clip.source || 'Unknown' },
          { label: 'Copied', value: new Date(clip.copiedAt).toLocaleString() },
          { label: 'Times copied', value: clip.copies },
        ]}
      />
    {/if}
  {/snippet}
</DetailLayout>
