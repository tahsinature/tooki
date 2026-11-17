<script lang="ts">
  import { onDestroy } from 'svelte';
  import { ChevronLeft, Copy, Check, File } from '@lucide/svelte';
  import { request, type ShelfItem } from './api';
  let {
    shelf,
    item,
    image,
    bytes,
    position,
    total,
    onback,
    onheight,
  }: {
    shelf: string;
    item: ShelfItem;
    image?: string;
    bytes?: number;
    position: number;
    total: number;
    onback: () => void;
    onheight: (height: number) => void;
  } = $props();
  let content: HTMLDivElement;
  $effect(() => {
    if (!content) return;
    const observer = new ResizeObserver(() =>
      onheight(Math.ceil(content.getBoundingClientRect().height) + 14),
    );
    observer.observe(content);
    return () => observer.disconnect();
  });
  let copied = $state(''),
    error = $state('');
  let timer: ReturnType<typeof setTimeout> | undefined;
  onDestroy(() => clearTimeout(timer));
  const size = $derived(
    bytes == null
      ? 'Unavailable'
      : bytes >= 1048576
        ? `${(bytes / 1048576).toFixed(1)} MB`
        : bytes >= 1024
          ? `${Math.round(bytes / 1024)} KB`
          : `${bytes} B`,
  );
  const original = $derived(
    item.originalPath ?? (item.owned ? null : item.path),
  );
  async function copy(originalPath = false) {
    try {
      await request('selection', {
        shelf,
        items: [item.id],
        action:
          originalPath && item.originalPath ? 'copyOriginalPath' : 'copyPath',
      });
      copied = originalPath ? 'original' : 'path';
      clearTimeout(timer);
      timer = setTimeout(() => (copied = ''), 1200);
    } catch (e) {
      error = String(e);
    }
  }
</script>

<section class="shelf-item-detail" aria-label="File details">
  <div class="detail-content" bind:this={content}>
    <header>
      <button onclick={onback}><ChevronLeft size={12} /> All items</button><span
        >{position} / {total}</span
      >
    </header>
    <div class="identity">
      {#if image}<img src={image} alt="" />{:else}<File size={40} />{/if}
      <div>
        <strong>{item.name}</strong><small class:owned={item.owned}
          >{item.owned ? 'Copy' : 'Original'}</small
        >
      </div>
    </div>
    <dl>
      <dt>Mode</dt>
      <dd>{item.owned ? 'Tooki-owned copy' : 'Reference to original'}</dd>
      <dt>Size</dt>
      <dd>{size}</dd>
      <dt>Path</dt>
      <dd>
        <span title={item.path}>{item.path}</span><button
          title="Copy full path"
          aria-label="Copy full path"
          onclick={() => void copy()}
          >{#if copied === 'path'}<Check size={11} />{:else}<Copy
              size={11}
            />{/if}</button
        >
      </dd>
      <dt>Original</dt>
      <dd>
        {#if original}<span title={original}>{original}</span><button
            title="Copy original path"
            aria-label="Copy original path"
            onclick={() => void copy(true)}
            >{#if copied === 'original'}<Check size={11} />{:else}<Copy
                size={11}
              />{/if}</button
          >{:else}None. Tooki made this file.{/if}
      </dd>
    </dl>
    {#if error}<p role="alert">{error}</p>{/if}
  </div>
</section>

<style>
  .shelf-item-detail {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 2px 14px 12px;
    flex: 1;
    min-height: 0;
    overflow: auto;
  }
  .detail-content {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 11px;
    color: var(--muted);
  }
  button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 3px;
    background: transparent;
    border-radius: var(--radius-small);
    color: var(--muted);
    padding: 2px;
    flex-shrink: 0;
  }
  header button {
    font-size: 11px;
    font-weight: 600;
    color: var(--accent);
  }
  .identity {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .identity img {
    width: 40px;
    height: 40px;
    object-fit: contain;
    flex-shrink: 0;
  }
  .identity > div {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    min-width: 0;
  }
  strong {
    font-size: 13px;
    display: -webkit-box;
    line-clamp: 2;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    overflow-wrap: anywhere;
  }
  small {
    font-size: 10px;
    border-radius: var(--radius-row);
    padding: 1px 6px;
    color: #ff9f0a;
    background: #ff9f0a20;
  }
  small.owned {
    color: #30d158;
    background: #30d15820;
  }
  dl {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: 7px 10px;
    margin: 0;
    font-size: 11px;
  }
  dt {
    color: var(--muted);
    text-align: right;
  }
  dd {
    display: flex;
    gap: 4px;
    align-items: flex-start;
    margin: 0;
    min-width: 0;
  }
  dd span {
    display: -webkit-box;
    line-clamp: 3;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
    overflow-wrap: anywhere;
  }
  p {
    font-size: 11px;
    color: var(--muted);
  }
</style>
