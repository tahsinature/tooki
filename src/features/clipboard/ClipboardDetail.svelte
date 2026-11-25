<script lang="ts">
  import { request, type Clip, type FileImagePreview } from './api';
  import DetailLayout from '../../components/DetailLayout.svelte';
  import InformationList from '../../components/InformationList.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import RecognizedText from './RecognizedText.svelte';
  let {
    id,
    revision = 0,
    showingText = false,
    textRevision = 0,
    onshowimage,
  }: {
    id?: string;
    revision?: number;
    showingText?: boolean;
    textRevision?: number;
    onshowimage: () => void;
  } = $props();
  let clip = $state<Clip>();
  let image = $state('');
  let imageLoading = $state(false);
  let fileImage = $state<FileImagePreview | null>(null);
  let error = $state('');
  let loadedId: string | undefined;
  $effect(() => {
    const selected = id;
    revision;
    let cancelled = false;
    if (loadedId !== selected) {
      clip = undefined;
      image = '';
      fileImage = null;
      imageLoading = false;
      loadedId = selected;
    }
    error = '';
    if (selected)
      void request<Clip>('detail', { id: selected })
        .then(async (value) => {
          if (cancelled) return;
          clip = value;
          if (value.image) {
            imageLoading = true;
            const data = await request<string>('image', { id: selected });
            if (!cancelled) image = data;
          } else if (value.kind === 'file' && value.files.length === 1) {
            imageLoading = true;
            const preview = await request<FileImagePreview | null>(
              'fileImage',
              { id: selected },
            );
            if (!cancelled) {
              fileImage = preview;
              image = preview?.data ?? '';
            }
          }
          if (!cancelled) imageLoading = false;
        })
        .catch((e) => {
          if (!cancelled) {
            imageLoading = false;
            error = String(e);
          }
        });
    return () => {
      cancelled = true;
    };
  });
</script>

<DetailLayout label="Clipboard preview">
  {#if error}<p role="alert">{error}</p>
  {:else if clip}
    {#if clip.kind === 'image' && showingText}
      {#key clip.id}<RecognizedText
          id={clip.id}
          revision={textRevision}
          {onshowimage}
        />{/key}
    {:else if image}<img
        class="clipboard-image"
        src={image}
        alt={clip.title}
        onerror={() => {
          image = '';
          fileImage = null;
          if (clip?.kind === 'image')
            error = 'The image preview is unavailable.';
        }}
      />
    {:else if imageLoading}<p class="muted">Loading image…</p>
    {:else if clip.kind === 'image'}<p class="muted">
        The image preview is unavailable.
      </p>
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
      description={id ? '' : 'Choose an item to see its preview.'}
    />{/if}
  {#snippet information()}
    {#if clip}
      <InformationList
        entries={[
          { label: 'Type', value: clip.kind },
          ...(clip.kind === 'image' || fileImage
            ? [
                {
                  label: 'Dimensions',
                  value: `${fileImage?.width ?? clip.width} × ${fileImage?.height ?? clip.height} px`,
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
