<script lang="ts">
  import { preferences } from '../../lib/preferences.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { noteFontFamily } from './fonts';
  import { Editor, getSchema, type JSONContent } from '@tiptap/core';
  import StarterKit from '@tiptap/starter-kit';
  import { TaskList, TaskItem } from '@tiptap/extension-list';
  import { Search, ChevronUp, ChevronDown, X } from '@lucide/svelte';
  import NoteToolbar from './NoteToolbar.svelte';
  import Dialog from '../../components/Dialog.svelte';
  import { findMatches } from './find';
  let {
    document,
    onchange,
    onready,
    onerror,
    findOpen = $bindable(false),
  }: {
    document: JSONContent;
    onchange: (document: JSONContent, text: string) => void;
    onready: (editor: Editor) => void;
    onerror: (message: string) => void;
    findOpen?: boolean;
  } = $props();
  let element: HTMLDivElement;
  let scroll: HTMLDivElement;
  let editor = $state.raw<Editor>();
  let revision = $state(0);
  let query = $state('');
  let matchIndex = $state(0);
  let search = $state<HTMLInputElement>();
  let linkOpen = $state(false);
  let link = $state('');
  let linkError = $state('');
  let matches = $derived.by(() => {
    revision;
    return editor ? findMatches(editor.state.doc, query) : [];
  });
  onMount(() => {
    try {
      // Validate before mounting so unsupported content is never silently stripped and autosaved.
      const extensions = [
        StarterKit.configure({
          link: { openOnClick: false, autolink: false },
        }),
        TaskList,
        TaskItem.configure({
          nested: true,
          HTMLAttributes: { 'data-type': 'taskItem' },
        }),
      ];
      getSchema(extensions).nodeFromJSON(document).check();
      const instance = new Editor({
        element,
        extensions,
        content: document,
        autofocus: 'end',
        enableContentCheck: true,
        editorProps: {
          attributes: {
            class: 'note-prose',
            role: 'textbox',
            'aria-label': 'Note content',
            'aria-multiline': 'true',
            spellcheck: 'true',
          },
        },
        onUpdate: ({ editor }) => onchange(editor.getJSON(), editor.getText()),
        onTransaction: () => revision++,
        onContentError: () => {
          onerror(
            'This note contains unsupported formatting. Its stored content has been kept.',
          );
        },
      });
      editor = instance;
      onready(instance);
      return () => instance.destroy();
    } catch (e) {
      onerror(`Could not open this note: ${e}`);
    }
  });
  $effect(() => {
    if (findOpen) void tick().then(() => search?.focus());
  });
  $effect.pre(() => {
    preferences.notesFont;
    const top = untrack(() => scroll?.scrollTop);
    if (top !== undefined)
      void tick().then(() => {
        if (scroll) scroll.scrollTop = top;
      });
  });
  function chooseMatch(step = 0) {
    if (!editor || !matches.length) return;
    matchIndex = (matchIndex + step + matches.length) % matches.length;
    editor.chain().setTextSelection(matches[matchIndex]).scrollIntoView().run();
  }
  function editLink() {
    link = editor?.getAttributes('link').href ?? '';
    linkError = '';
    linkOpen = true;
  }
  function applyLink() {
    if (!editor) return;
    if (link.trim() && !/^(https?:\/\/|mailto:)/i.test(link.trim())) {
      linkError = 'Use an https://, http:// or mailto: link.';
      return;
    }
    const chain = editor.chain().focus().extendMarkRange('link');
    if (link.trim()) chain.setLink({ href: link.trim() }).run();
    else chain.unsetLink().run();
    linkOpen = false;
  }
</script>

{#if editor && preferences.notesToolbar}<NoteToolbar
    {editor}
    {revision}
    onlink={editLink}
  />{/if}
{#if findOpen}
  <div class="note-find input-frame">
    <Search size={14} /><TextInput
      bind:element={search}
      value={query}
      aria-label="Find in note"
      placeholder="Find in note…"
      oninput={(event) => {
        query = event.currentTarget.value;
        matchIndex = 0;
        void tick().then(() => chooseMatch());
      }}
      onkeydown={(event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          chooseMatch(event.shiftKey ? -1 : 1);
        } else if (event.key === 'Escape') {
          event.preventDefault();
          event.stopPropagation();
          findOpen = false;
          editor?.commands.focus();
        }
      }}
    />
    <span
      >{matches.length
        ? `${Math.min(matchIndex + 1, matches.length)} of ${matches.length}`
        : '0 matches'}</span
    >
    <button
      class="icon-button"
      aria-label="Previous match"
      disabled={!matches.length}
      onclick={() => chooseMatch(-1)}><ChevronUp size={14} /></button
    >
    <button
      class="icon-button"
      aria-label="Next match"
      disabled={!matches.length}
      onclick={() => chooseMatch(1)}><ChevronDown size={14} /></button
    >
    <button
      class="icon-button"
      aria-label="Close find"
      onclick={() => {
        findOpen = false;
        editor?.commands.focus();
      }}><X size={14} /></button
    >
  </div>
{/if}
<div
  class="note-editor-scroll"
  bind:this={scroll}
  style:--note-font={noteFontFamily(preferences.notesFont)}
>
  <div bind:this={element}></div>
</div>
{#if linkOpen}<Dialog
    title="Edit link"
    onclose={() => {
      linkOpen = false;
      editor?.commands.focus();
    }}
  >
    <form
      class="note-link-form"
      onsubmit={(event) => {
        event.preventDefault();
        applyLink();
      }}
    >
      <label for="note-link">Link address</label><TextInput
        id="note-link"
        class="text-field"
        bind:value={link}
        placeholder="https://example.com"
      />
      {#if linkError}<p role="alert">{linkError}</p>{/if}
      <button
        class="note-text-button"
        type="button"
        onclick={() => {
          linkOpen = false;
          editor?.commands.focus();
        }}>Cancel</button
      >
      <button class="note-text-button" type="submit"
        >{link.trim() ? 'Apply link' : 'Remove link'}</button
      >
    </form>
  </Dialog>{/if}
