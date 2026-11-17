<script lang="ts">
  import RenameInput from '../../components/RenameInput.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import { onMount } from 'svelte';
  import {
    SquareStack,
    List,
    Ellipsis,
    Minus,
    Trash2,
    ChevronDown,
    ChevronUp,
    File,
    Copy,
    ArrowUpRight,
    Archive,
  } from '@lucide/svelte';
  import { FloatingShelfController } from './floating-controller.svelte';
  import './floating-shelf.css';
  import FloatingSurface from '../../components/FloatingSurface.svelte';
  import WindowControlGroup from '../../components/WindowControlGroup.svelte';
  import ShelfItemRow from './ShelfItemRow.svelte';
  import ShelfItemDetail from './ShelfItemDetail.svelte';
  import ShelfConversion from './ShelfConversion.svelte';
  const model = new FloatingShelfController(
    new URLSearchParams(location.search).get('shelf')!,
  );
  const size = $derived(
    model.bytes >= 1048576
      ? `${(model.bytes / 1048576).toFixed(1)} MB`
      : model.bytes >= 1024
        ? `${Math.round(model.bytes / 1024)} KB`
        : `${model.bytes} B`,
  );
  $effect(() => {
    model.conversion.length;
    model.expanded;
    model.detail;
    model.detailHeight;
    model.drop;
    model.editing;
    model.shelf.items.length;
    void model.resize();
  });
  onMount(() => {
    void model.mount();
    return () => model.dispose();
  });
  function renameKey(event: KeyboardEvent) {
    event.stopPropagation();
    if (event.key === 'Enter' || event.key === 'Escape') event.preventDefault();
    if (event.key === 'Enter') void model.saveName();
    if (event.key === 'Escape') model.editing = '';
  }
</script>

<svelte:window
  onkeydown={(e) => model.keyboard(e)}
  onkeyup={(e) => model.keyup(e)}
  onblur={() => model.blur()}
/>
<FloatingSurface
  class={`floating-shelf ${model.holding ? 'holding' : ''} ${model.leaving ? 'leaving' : ''}`}
  keepOnTop={model.keepOnTop || !!model.drop}
  label={model.shelf.name}
>
  <header class="shelf-header">
    {#if model.editing === 'shelf'}<RenameInput
        label="Shelf name"
        value={model.name}
        oncommit={(name) => {
          model.name = name;
          void model.saveName();
        }}
        oncancel={() => (model.editing = '')}
      />{:else}<strong
        data-tauri-drag-region
        ondblclick={() => model.edit('shelf')}>{model.shelf.name}</strong
      >{/if}
    {#if model.shelf.items.length}<WindowControlGroup label="Shelf view">
        <button
          aria-label="Show as a stack"
          title="Show as a stack"
          aria-pressed={!model.expanded}
          onclick={() => {
            model.expanded = false;
            model.detail = false;
          }}><SquareStack size={12} /></button
        ><button
          aria-label="Show as a list"
          title="Show as a list"
          aria-pressed={model.expanded}
          onclick={() => (model.expanded = true)}><List size={12} /></button
        >
      </WindowControlGroup>{/if}
    <button
      class="floating-round"
      aria-label="Shelf actions"
      title="Shelf actions"
      onclick={(e) => void model.menu(e)}><Ellipsis size={12} /></button
    >
    <button
      class="floating-round"
      class:destructive={model.option || model.armed === 'deleteShelf'}
      aria-label={model.option ? 'Delete shelf' : 'Hide shelf'}
      title="Hide shelf. Hold Option to delete."
      onclick={() =>
        model.option || model.armed === 'deleteShelf'
          ? void model.destructive('deleteShelf')
          : void model.hide()}
      >{#if model.armed === 'deleteShelf'}<span>Delete?</span
        >{:else if model.option}<Trash2 size={11} />{:else}<Minus
          size={12}
        />{/if}</button
    >
  </header>
  {#if model.conversion.length}<ShelfConversion
      shelf={model.id}
      items={model.conversion}
      onclose={() => (model.conversion = [])}
      onsaved={() => void model.refreshConvertedFiles()}
    />{:else if model.editing === 'item'}<form
      class="shelf-rename"
      onsubmit={(e) => {
        e.preventDefault();
        void model.saveName();
      }}
    >
      <label for="shelf-file-name">Rename file</label>
      <p>
        {model.current?.owned
          ? 'Renames Tooki’s copy. The original keeps its name.'
          : 'Renames the original file on disk.'}
      </p>
      <TextInput
        id="shelf-file-name"
        class="text-field"
        data-shelf-rename
        bind:value={model.name}
        onkeydown={renameKey}
      />
      <div>
        <button type="button" onclick={() => (model.editing = '')}
          >Cancel</button
        ><button type="submit">Rename</button>
      </div>
    </form>
  {:else if !model.shelf.items.length}<div class="shelf-empty">
      <Archive size={24} /><strong>Drop files here</strong><span
        >or paste from the clipboard</span
      >
    </div>
  {:else if model.detail && model.current}<ShelfItemDetail
      shelf={model.id}
      item={model.current}
      image={model.previews[model.current.path]}
      bytes={model.metadata.bytes}
      position={model.shelf.items.findIndex(
        (item) => item.id === model.current?.id,
      ) + 1}
      total={model.shelf.items.length}
      onheight={(height) => (model.detailHeight = height)}
      onback={() => (model.detail = false)}
    />
  {:else if model.expanded}<div
      class="shelf-rows"
      role="listbox"
      aria-multiselectable="true"
      aria-label="Shelf items"
    >
      {#each model.shelf.items as item}<ShelfItemRow
          {item}
          image={model.previews[item.path]}
          bytes={model.itemBytes[item.id]}
          selected={model.selection.ids.includes(item.id)}
          onclick={(e) =>
            void model.select(
              item.id,
              false,
              e.shiftKey || e.metaKey || e.ctrlKey,
            )}
          onopen={() => void model.act('open', { item: item.id })}
          oninfo={() => {
            void model.select(item.id);
            void model.showDetail();
          }}
          oncontextmenu={(e) => void model.context(e, item.id)}
          onpointerdown={(e) => model.gesture(e, item.id)}
        />
      {/each}
    </div>
  {:else}<div class="shelf-stack" data-tauri-drag-region>
      <button
        class="shelf-pile"
        aria-label="Show all items or drag the stack"
        oncontextmenu={(e) => void model.context(e)}
        onpointerdown={(e) => model.gesture(e)}
        >{#each model.recent as item, index}<span
            style={`--pile-index:${index};--pile-count:${model.recent.length}`}
            >{#if model.previews[item.path]}<img
                src={model.previews[item.path]}
                alt=""
              />{:else}<File size={44} />{/if}</span
          >{/each}</button
      >
      <div class="shelf-names">
        {#each model.recent as item}<div title={item.name}>
            <i class:copy={item.owned}></i><span>{item.name}</span>
          </div>{/each}{#if model.shelf.items.length > 3}<small
            >+ {model.shelf.items.length - 3} more</small
          >{/if}
      </div>
    </div>{/if}
  {#if model.shelf.items.length && !model.editing && !model.conversion.length}<footer
      class="shelf-bottom"
      class:expanded={model.expanded}
    >
      {#if model.expanded}<div
          class="shelf-footer-summary"
          data-tauri-drag-region
        >
          <button
            aria-label="Show stack"
            onclick={() => {
              model.expanded = false;
              model.detail = false;
            }}><ChevronUp size={14} /></button
          ><span
            >{model.selection.ids.length
              ? `${model.selection.ids.length} of ${model.shelf.items.length} selected`
              : `${model.shelf.items.length} ${model.shelf.items.length === 1 ? 'item' : 'items'} · ${size}`}</span
          >
        </div>
        {#if model.detail}<button
            onclick={() => void model.runSelection('reveal')}>Reveal</button
          >{/if}
      {:else}<button onclick={() => (model.expanded = true)}
          >Show {model.shelf.items.length}
          {model.shelf.items.length === 1 ? 'item' : 'items'}<span
            >· {size}</span
          ><ChevronDown size={11} /></button
        >{/if}
      <button
        disabled={model.busy}
        class:destructive={model.armed === 'clear'}
        onclick={() => void model.destructive('clear')}
        >{model.armed === 'clear' ? 'Clear?' : 'Clear'}</button
      >
    </footer>{/if}
  {#if model.drop}<div class="shelf-drop">
      {#if model.drop === 'content'}<div class="active copy">
          <Copy size={19} /><strong>Save to shelf</strong><small
            >Text, links and images are kept as a copy.</small
          >
        </div>{:else}<div class:active={model.drop === 'original'}>
          <ArrowUpRight size={19} /><strong>Link to original</strong><small
            >Moves when dragged out</small
          >
        </div>
        <div class:active={model.drop === 'copy'} class="copy">
          <Copy size={19} /><strong>Make a copy</strong><small
            >Original stays put</small
          >
        </div>{/if}
    </div>{/if}
  {#if model.holding}<div class="shelf-hold">
      <Trash2 size={24} /><strong>Hold to delete shelf</strong><span
        >Release to cancel</span
      >
    </div>{/if}
  {#if model.importing}<div class="shelf-copy-progress" role="status">
      Adding {model.importing.done + 1} of {model.importing.total}…
    </div>{/if}
  {#if model.error}<div class="shelf-error" role="alert">
      <button title={model.error} onclick={() => (model.error = '')}
        >{model.error}</button
      >
    </div>{/if}
</FloatingSurface>
