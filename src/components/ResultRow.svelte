<script lang="ts">
  import {
    Smile,
    TextCursorInput,
    Image,
    Folder,
    Palette,
    ClipboardList,
    FileText,
    Link,
    Code,
    Pin,
    Star,
    AppWindow,
    NotebookPen,
    Layers,
    Settings,
    Moon,
    Coffee,
    Trash2,
    HardDriveUpload,
  } from '@lucide/svelte';
  import Keycap from './Keycap.svelte';
  import type { Item } from '../lib/data';
  let {
    item,
    selected,
    index,
    onclick,
    onopen,
  }: {
    item: Item;
    selected: boolean;
    index: number;
    onclick: () => void;
    onopen: () => void;
  } = $props();
  const icons = {
    application: AppWindow,
    command: ClipboardList,
    text: FileText,
    link: Link,
    code: Code,
    image: Image,
    file: Folder,
    color: Palette,
  };
  const toolIcons = {
    emoji: Smile,
    'command:emoji.open': Smile,
    snippets: TextCursorInput,
    notes: NotebookPen,
    shelf: Layers,
    system: Settings,
    keepAwake: Coffee,
    'command:system.sleep': Moon,
    'command:system.emptyTrash': Trash2,
    'command:system.eject': HardDriveUpload,
    settings: Settings,
    clipboard: ClipboardList,
  };
  let Icon = $derived(
    item.kind === 'command'
      ? item.id.startsWith('snippet:') || item.id === 'command:snippets.open'
        ? TextCursorInput
        : item.id.startsWith('command:system.keepAwake')
          ? Coffee
          : (toolIcons[item.id as keyof typeof toolIcons] ?? ClipboardList)
      : icons[item.kind],
  );
</script>

<button
  class="result-row"
  class:selected
  data-index={index}
  title={item.subtitle}
  aria-current={selected ? 'true' : undefined}
  {onclick}
  ondblclick={onopen}
  onkeydown={(event) => {
    if (event.key === 'Enter' && !event.metaKey && !event.ctrlKey) {
      event.preventDefault();
      onopen();
    }
  }}
>
  <span class="item-icon"
    >{#if item.icon}<img
        src={item.icon}
        alt=""
        width="24"
        height="24"
      />{:else}<Icon size={18} strokeWidth={1.7} />{/if}</span
  >
  <span class="row-copy"
    ><span class="row-title-line">
      <span class="row-title">{item.title}</span>
      {#if item.kind === 'application' && item.alias?.trim()}
        <span
          class="row-alias"
          title={`Alias: ${item.alias}`}
          aria-label={`Alias: ${item.alias}`}>{item.alias}</span
        >
      {/if}
    </span></span
  >
  {#if item.pinned}{#if item.kind === 'application'}<Star
        size={12}
        class="muted"
      />{:else}<Pin size={12} class="muted" />{/if}{/if}
  <span class="row-metadata"
    >{item.kind === 'command'
      ? 'Command'
      : item.kind === 'link'
        ? 'Link'
        : item.kind.charAt(0).toUpperCase() + item.kind.slice(1)}</span
  >
  <span class="row-enter" aria-hidden="true"><Keycap text="↵" /></span>
</button>
