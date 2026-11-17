<script lang="ts">
  import { onDestroy } from 'svelte';
  import { watchQuickLook } from '../../lib/quickLook';
  import { ArrowLeft, Eye, ChevronLeft, ChevronRight } from '@lucide/svelte';
  import { request } from './api';
  import { showShelfMenu } from './native-menu';
  let {
    shelf,
    items,
    onclose,
    onsaved,
  }: {
    shelf: string;
    items: string[];
    onclose: () => void;
    onsaved: () => void;
  } = $props();
  let format = $state('jpeg'),
    size = $state('0'),
    metadata = $state(true),
    busy = $state(false),
    error = $state('');
  let preview = $state<{
    session: string;
    errors: { name: string; error: string }[];
    results: {
      item: string;
      name: string;
      image: string | null;
      bytes: number;
      beforeBytes: number;
    }[];
  } | null>(null);
  let index = $state(0),
    confirm = $state(false),
    disposed = false;
  const current = $derived(preview?.results[index]);
  const previewContext = $derived(
    preview ? `conversion:${preview.session}` : '',
  );
  $effect(() =>
    watchQuickLook(previewContext, (direction) => {
      if (!busy && preview)
        index = Math.max(
          0,
          Math.min(preview.results.length - 1, index + direction),
        );
    }),
  );
  $effect(() => {
    const session = preview?.session;
    const selected = index;
    if (session)
      void request('updateConversionPreview', {
        session,
        index: selected,
      }).catch((e) => (error = String(e)));
  });
  onDestroy(() => {
    disposed = true;
    if (preview)
      void request('discardConversion', { session: preview.session });
  });
  async function prepare() {
    busy = true;
    error = '';
    try {
      const result = await request<NonNullable<typeof preview>>(
        'prepareConversion',
        { shelf, items, format, size: Number(size), metadata },
      );
      if (disposed) {
        void request('discardConversion', { session: result.session });
        return;
      }
      preview = result;
      index = 0;
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
  async function save(replace: boolean) {
    if (replace && !confirm) {
      confirm = true;
      return;
    }
    busy = true;
    error = '';
    try {
      await request('saveConversion', {
        shelf,
        session: preview?.session,
        replace,
      });
      preview = null;
      onsaved();
      onclose();
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
  async function reload() {
    if (!preview || busy) return;
    const selected = index;
    busy = true;
    error = '';
    try {
      const update = await request<{ bytes: number; image: string | null }>(
        'refreshConversion',
        { session: preview.session, index: selected },
      );
      preview.results[selected] = { ...preview.results[selected], ...update };
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
  async function openWith(event: MouseEvent) {
    if (!preview) return;
    const session = preview.session,
      selected = index;
    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
    try {
      const apps = await request<{ name: string; path: string }[]>(
        'conversionApps',
        { session, index: selected },
      );
      await showShelfMenu(
        apps.length
          ? apps.map((app) => ({
              text: app.name,
              action: () =>
                void request('openConversion', {
                  session,
                  index: selected,
                  app: app.path,
                }).catch((e) => (error = String(e))),
            }))
          : [{ text: 'No compatible apps', enabled: false }],
        { x: rect.left, y: rect.bottom },
      );
    } catch (e) {
      error = String(e);
    }
  }
  function back() {
    if (preview) {
      void request('discardConversion', { session: preview.session });
      preview = null;
      confirm = false;
    } else onclose();
  }
</script>

<section class="shelf-conversion" aria-label="Convert images">
  <header>
    <button disabled={busy} onclick={back} aria-label="Back"
      ><ArrowLeft size={14} /></button
    ><strong
      >{preview
        ? 'Review conversion'
        : `Convert ${items.length === 1 ? 'image' : 'images'}`}</strong
    >
  </header>
  {#if current}<div class="conversion-review">
      {#if current.image}<img
          src={current.image}
          alt={current.name}
        />{/if}<strong>{current.name}</strong><span
        >{Math.round(current.beforeBytes / 1024)} KB → {Math.round(
          current.bytes / 1024,
        )} KB</span
      >
      <div class="conversion-navigation">
        <button
          disabled={busy || index === 0}
          onclick={() => index--}
          aria-label="Previous image"><ChevronLeft size={14} /></button
        ><span>{index + 1} of {preview!.results.length}</span><button
          disabled={busy || index === preview!.results.length - 1}
          onclick={() => index++}
          aria-label="Next image"><ChevronRight size={14} /></button
        ><button
          onclick={() =>
            void request('previewConversion', {
              session: preview!.session,
              index,
            }).catch((e) => (error = String(e)))}
          ><Eye size={14} /> Quick Look</button
        >
      </div>
    </div>
    <div class="conversion-edit">
      <button disabled={busy} onclick={(e) => void openWith(e)}
        >Open With…</button
      ><button disabled={busy} onclick={() => void reload()}
        >Reload preview</button
      >
    </div>
    {#if preview?.errors.length}<details class="conversion-errors">
        <summary
          >{preview.errors.length}
          {preview.errors.length === 1 ? 'image could' : 'images could'} not be converted</summary
        >{#each preview.errors as failure}<p>
            <strong>{failure.name}</strong>: {failure.error}
          </p>{/each}
      </details>{/if}
    {#if confirm}<p class="conversion-warning">
        Replace the source files? This changes originals on disk and cannot be
        undone.
      </p>{/if}
    <footer>
      <button disabled={busy} onclick={() => void save(false)}
        >Save new copies</button
      ><button
        disabled={busy}
        class:danger={confirm}
        onclick={() => void save(true)}
        >{confirm ? 'Confirm replacement' : 'Replace files…'}</button
      >
    </footer>
  {:else}<div class="conversion-options">
      <label
        >Format<select bind:value={format} disabled={busy}
          ><option value="jpeg">JPEG</option><option value="png">PNG</option
          ><option value="heif">HEIF</option></select
        ></label
      ><label
        >Size<select bind:value={size} disabled={busy}
          ><option value="0">Actual size</option><option value="1920"
            >Large (1920 px)</option
          ><option value="1280">Medium (1280 px)</option><option value="640"
            >Small (640 px)</option
          ></select
        ></label
      ><label
        >Preserve metadata<input
          type="checkbox"
          bind:checked={metadata}
          disabled={busy}
        /></label
      >
    </div>
    <p>
      Review the converted images before saving. Source files stay unchanged
      until you choose Replace.
    </p>
    <footer>
      <button disabled={busy} onclick={() => void prepare()}
        >{busy ? 'Converting…' : 'Convert and review'}</button
      >
    </footer>{/if}
  {#if error}<p role="alert" class="conversion-warning">{error}</p>{/if}
</section>

<style>
  .shelf-conversion {
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-height: 0;
    height: 100%;
    padding: 10px 12px;
    font-size: 12px;
    background: var(--panel);
    color: var(--ink);
    overflow: auto;
  }
  .shelf-conversion header {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .shelf-conversion button,
  .shelf-conversion select {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
    border: 1px solid var(--line);
    border-radius: var(--radius-control);
    padding: 5px 8px;
    background: var(--hover);
    color: var(--ink);
    font: inherit;
  }
  .shelf-conversion button:hover {
    background: var(--selected);
  }
  .shelf-conversion button:disabled {
    opacity: 0.5;
  }
  .conversion-options {
    display: flex;
    flex-direction: column;
    margin-top: 6px;
  }
  .conversion-options label {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    padding: 8px 0;
    border-bottom: 1px solid var(--line);
  }
  .shelf-conversion p {
    color: var(--muted);
    font-size: 11px;
    line-height: 1.5;
    margin: 0;
  }
  .shelf-conversion footer {
    display: flex;
    gap: 6px;
    margin-top: auto;
    justify-content: end;
  }
  .conversion-review {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 5px;
    min-height: 0;
  }
  .conversion-review img {
    width: 100%;
    height: 125px;
    object-fit: contain;
  }
  .conversion-review strong {
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .conversion-review > span {
    font-size: 11px;
    color: var(--muted);
  }
  .conversion-edit {
    display: flex;
    gap: 6px;
    justify-content: center;
  }
  .conversion-errors {
    font-size: 11px;
    color: var(--muted);
  }
  .conversion-navigation {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 10px;
  }
  .shelf-conversion .conversion-warning {
    color: #e99161;
  }
  .shelf-conversion .danger {
    background: #b93636;
    color: white;
  }
</style>
