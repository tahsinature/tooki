<script lang="ts">
  import { File, Info } from '@lucide/svelte';
  import type { ShelfItem } from './api';
  let {
    item,
    image,
    bytes,
    selected,
    onclick,
    onopen,
    oninfo,
    oncontextmenu,
    onpointerdown,
  }: {
    item: ShelfItem;
    image?: string;
    bytes?: number;
    selected: boolean;
    onclick: (e: MouseEvent) => void;
    onopen: () => void;
    oninfo: () => void;
    oncontextmenu: (e: MouseEvent) => void;
    onpointerdown: (e: PointerEvent) => void;
  } = $props();
  const size = $derived(
    bytes == null
      ? ''
      : bytes >= 1048576
        ? `${(bytes / 1048576).toFixed(1)} MB`
        : bytes >= 1024
          ? `${Math.round(bytes / 1024)} KB`
          : `${bytes} B`,
  );
</script>

<div class="shelf-item" class:selected>
  <button
    class="shelf-item-main"
    role="option"
    aria-selected={selected}
    data-shelf-item={item.id}
    {onclick}
    ondblclick={onopen}
    {oncontextmenu}
    {onpointerdown}
    title={item.path}
    ><span class="shelf-item-icon"
      >{#if image}<img src={image} alt="" />{:else}<File size={18} />{/if}<i
        class:copy={item.owned}
      ></i></span
    ><span class="shelf-item-name">{item.name}</span><span
      class="shelf-item-size">{size}</span
    ></button
  >
  <button
    class="shelf-item-info"
    aria-label={`Details for ${item.name}`}
    onclick={oninfo}><Info size={12} /></button
  >
</div>

<style>
  .shelf-item {
    position: relative;
    border-radius: var(--radius-control);
    height: 30px;
    flex-shrink: 0;
  }
  .shelf-item.selected {
    background: var(--selected);
  }
  .shelf-item:hover {
    background: var(--hover);
  }
  .shelf-item.selected:hover {
    background: var(--selected);
  }
  .shelf-item-main {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    height: 30px;
    padding: 0 8px;
    background: transparent;
    font-size: 12px;
    text-align: left;
  }
  .shelf-item-icon {
    position: relative;
    display: grid;
    place-items: center;
    width: 18px;
    height: 22px;
    flex: 0 0 18px;
  }
  .shelf-item-icon img {
    width: 18px;
    height: 22px;
    object-fit: contain;
  }
  .shelf-item-icon i {
    position: absolute;
    bottom: 0;
    right: -2px;
    width: 5px;
    height: 5px;
    border-radius: 50%;
    box-shadow: 0 0 0 1px var(--panel);
  }
  .shelf-item-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .shelf-item-size {
    color: var(--muted);
    font-size: 10px;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .shelf-item-info {
    position: absolute;
    right: 4px;
    top: 2px;
    display: grid;
    place-items: center;
    width: 26px;
    height: 26px;
    padding: 0;
    background: transparent;
    opacity: 0;
  }
  .shelf-item:hover .shelf-item-info,
  .shelf-item:focus-within .shelf-item-info {
    opacity: 1;
  }
  .shelf-item:hover .shelf-item-size,
  .shelf-item:focus-within .shelf-item-size {
    opacity: 0;
  }
</style>
