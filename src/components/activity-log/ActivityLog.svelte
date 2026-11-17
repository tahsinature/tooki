<script lang="ts">
  import TextInput from '../TextInput.svelte';
  import { tick, untrack } from 'svelte';
  import {
    createVirtualizer,
    defaultRangeExtractor,
  } from '@tanstack/svelte-virtual';
  import { Search, ChevronRight, Copy, Download, Trash2 } from '@lucide/svelte';
  import Button from '../Button.svelte';
  import Keycap from '../Keycap.svelte';
  import PanelFilterMenu from '../PanelFilterMenu.svelte';
  import Toggle from '../Toggle.svelte';
  import {
    filterEntries,
    logText,
    logJson,
    nextRow,
    type ActivityLogEntry,
    type ActivityLogColumn,
  } from './model';
  import { copyLog, exportLog } from './export';
  import './activity-log.css';
  let {
    entries,
    columns,
    filters,
    title = 'Activity',
    emptyMessage = 'No activity yet.',
    filename = 'activity-log.json',
    onclear,
  }: {
    entries: ActivityLogEntry[];
    columns: ActivityLogColumn[];
    filters: { value: string; label: string }[];
    title?: string;
    emptyMessage?: string;
    filename?: string;
    onclear: () => void | Promise<void>;
  } = $props();
  const id = $props.id();
  let query = $state('');
  let searchInput = $state<HTMLInputElement>();
  let category = $state('all');
  let follow = $state(true);
  let expandedId = $state<string | null>(null);
  let focusedId = $state<string | null>(null);
  let viewport = $state<HTMLDivElement>();
  const rowButtons = new Map<string, HTMLButtonElement>();
  let pendingFocus: string | null = null;
  let message = $state('');
  let busy = $state(false);
  let filtered = $derived(filterEntries(entries, query, category));
  let focusedIndex = $derived(
    filtered.findIndex((entry) => entry.id === focusedId),
  );
  const getItemKey = (index: number) => filtered[index]?.id ?? index;
  const virtualizer = createVirtualizer<HTMLDivElement, HTMLDivElement>({
    count: 0,
    getScrollElement: () => viewport ?? null,
    estimateSize: () => 34,
    overscan: 5,
    getItemKey,
    rangeExtractor: (range) => {
      const indexes = defaultRangeExtractor(range);
      // Keep a focused row mounted when the user scrolls with the trackpad.
      if (focusedIndex >= 0 && !indexes.includes(focusedIndex))
        indexes.push(focusedIndex);
      return indexes.sort((a, b) => a - b);
    },
  });
  $effect(() => {
    const items = filtered;
    const count = items.length;
    const element = viewport;
    const focus = focusedIndex;
    untrack(() =>
      $virtualizer.setOptions({
        count,
        getScrollElement: () => element ?? null,
        getItemKey: (index) => items[index]?.id ?? index,
      }),
    );
    void focus;
  });
  $effect(() => {
    const last = filtered.at(-1)?.id;
    if (follow && last) {
      void tick().then(() => {
        if (follow)
          $virtualizer.scrollToIndex(filtered.length - 1, { align: 'end' });
      });
    }
  });
  $effect(() => {
    query;
    category;
    untrack(() => {
      expandedId = null;
      focusedId = null;
      viewport?.scrollTo({ top: 0 });
    });
  });
  function measure(node: HTMLDivElement) {
    $virtualizer.measureElement(node);
    return { destroy: () => $virtualizer.measureElement(null) };
  }
  function toggle(entry: ActivityLogEntry) {
    follow = false;
    focusedId = entry.id;
    expandedId = expandedId === entry.id ? null : entry.id;
  }
  function registerRow(node: HTMLButtonElement, entryId: string) {
    rowButtons.set(entryId, node);
    if (pendingFocus === entryId) {
      node.focus({ preventScroll: true });
      pendingFocus = null;
    }
    return { destroy: () => rowButtons.delete(entryId) };
  }
  async function keyboard(event: KeyboardEvent, index: number) {
    const next = nextRow(
      event.key,
      index,
      filtered.length,
      Math.max(1, Math.floor((viewport?.clientHeight ?? 260) / 34)),
      event.metaKey || event.ctrlKey,
    );
    if (next === null) return;
    event.preventDefault();
    event.stopPropagation();
    follow = false;
    focusedId = filtered[next].id;
    pendingFocus = focusedId;
    $virtualizer.scrollToIndex(next, { align: 'auto' });
    await tick();
    const button = rowButtons.get(filtered[next].id);
    if (button) {
      button.focus({ preventScroll: true });
      pendingFocus = null;
    }
  }
  function focusResults() {
    const index = $virtualizer.getVirtualItems()[0]?.index;
    const entry = index === undefined ? undefined : filtered[index];
    const target = entry ? rowButtons.get(entry.id) : undefined;
    (target ?? searchInput)?.focus({ preventScroll: true });
  }
  async function action(kind: 'copy' | 'export' | 'clear') {
    const selected = filtered;
    busy = true;
    message = '';
    try {
      if (kind === 'copy') {
        await copyLog(logText(selected, columns));
        message = `Copied ${selected.length} results.`;
      } else if (kind === 'export') {
        if (await exportLog(logJson(selected, columns), filename))
          message = `Exported ${selected.length} results.`;
      } else {
        await onclear();
        expandedId = null;
        focusedId = null;
        message = 'Results cleared.';
      }
    } catch (error) {
      message = String(error);
    } finally {
      busy = false;
    }
  }
</script>

<section
  class="activity-log"
  aria-label={title}
  style:--log-columns={`64px ${columns.map((column) => `minmax(0, ${column.weight ?? 1}fr)`).join(' ')} 14px`}
>
  <header class="activity-log-toolbar">
    <div class="activity-log-filters input-frame">
      <label class="activity-log-search"
        ><Search size={13} /><TextInput
          aria-label="Search activity"
          placeholder="Search results…"
          bind:value={query}
          bind:element={searchInput}
        /></label
      >
      <PanelFilterMenu
        bind:value={category}
        onapply={focusResults}
        options={filters}
        label="Filter activity"
      />
    </div>
    <div class="activity-log-actions">
      <Button
        disabled={busy || !filtered.length}
        onclick={() => void action('copy')}
        label="Copy matching results"><Copy size={12} />Copy</Button
      >
      <Button
        disabled={busy || !filtered.length}
        onclick={() => void action('export')}
        label="Export matching results"><Download size={12} />Export</Button
      >
      <Button
        disabled={busy || !entries.length}
        onclick={() => void action('clear')}
        label="Clear all results"><Trash2 size={12} />Clear</Button
      >
    </div>
  </header>
  <div class="activity-log-columns" aria-hidden="true">
    <span>Time</span>{#each columns as column}<span>{column.title}</span
      >{/each}<span></span>
  </div>
  <div
    class="activity-log-viewport"
    bind:this={viewport}
    role="list"
    aria-label={`${title} results`}
    onwheel={(event) => {
      if (event.deltaY < 0) follow = false;
    }}
  >
    {#if filtered.length}
      <div
        style:height={`${$virtualizer.getTotalSize()}px`}
        class="activity-log-canvas"
      >
        {#each $virtualizer.getVirtualItems() as item (item.key)}
          {@const entry = filtered[item.index]}
          <!-- Filtering can render before the virtualizer updates its range. -->
          {#if entry}<div
              class="activity-log-item"
              data-index={item.index}
              use:measure
              style:transform={`translateY(${item.start}px)`}
              role="listitem"
              aria-posinset={item.index + 1}
              aria-setsize={filtered.length}
            >
              <button
                use:registerRow={entry.id}
                class="activity-log-row"
                class:expanded={expandedId === entry.id}
                aria-expanded={expandedId === entry.id}
                aria-controls={`${id}-${entry.id}`}
                data-log-index={item.index}
                tabindex={focusedId === entry.id ||
                (!focusedId &&
                  item.index ===
                    (follow
                      ? filtered.length - 1
                      : $virtualizer.getVirtualItems()[0]?.index))
                  ? 0
                  : -1}
                onfocus={() => (focusedId = entry.id)}
                onclick={() => toggle(entry)}
                onkeydown={(event) => void keyboard(event, item.index)}
              >
                <time
                  datetime={new Date(entry.timestamp).toISOString()}
                  title={new Date(entry.timestamp).toLocaleString()}
                  >{new Date(entry.timestamp).toLocaleTimeString([], {
                    hour12: false,
                  })}</time
                >
                {#each columns as column}<span
                    class="activity-log-cell"
                    title={entry.cells[column.id]?.text}
                    >{#if entry.cells[column.id]?.keys}<span
                        class="activity-log-keycaps"
                        >{#each entry.cells[column.id].keys ?? [] as key}<Keycap
                            text={key}
                          />{/each}</span
                      >{:else}{entry.cells[column.id]?.text ?? '—'}{/if}</span
                  >{/each}
                <ChevronRight size={12} />
              </button>
              {#if expandedId === entry.id}<dl
                  id={`${id}-${entry.id}`}
                  class="activity-log-details"
                >
                  {#each entry.details as detail}<div>
                      <dt>{detail.label}</dt>
                      <dd>{detail.value}</dd>
                    </div>{/each}
                </dl>{/if}
            </div>{/if}
        {/each}
      </div>
    {:else}<div class="activity-log-empty">
        {entries.length ? 'No matching results.' : emptyMessage}
      </div>{/if}
  </div>
  <footer class="activity-log-footer">
    <span
      >{filtered.length === entries.length
        ? `${entries.length.toLocaleString()} results`
        : `${filtered.length.toLocaleString()} of ${entries.length.toLocaleString()} results`}</span
    ><label
      >Follow latest <Toggle
        label="Follow latest activity"
        checked={follow}
        onchange={(value) => (follow = value)}
      /></label
    >
  </footer>
  {#if message}<p class="activity-log-message" role="status">{message}</p>{/if}
</section>
