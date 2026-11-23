<script lang="ts">
  import SaveIndicator from './SaveIndicator.svelte';
  import { preferences, setPreference } from '../../lib/preferences.svelte';
  import { invoke } from '@tauri-apps/api/core';
  import RenameInput from '../../components/RenameInput.svelte';
  import { onMount, tick } from 'svelte';
  import FloatingSurface from '../../components/FloatingSurface.svelte';
  import WindowControlGroup from '../../components/WindowControlGroup.svelte';
  import { Ellipsis, Minus } from '@lucide/svelte';
  import { isTauri } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { writeText } from '@tauri-apps/plugin-clipboard-manager';
  import type { Editor, JSONContent } from '@tiptap/core';
  import { PanelsTopLeft, Plus, CircleAlert } from '@lucide/svelte';
  import { noteActions } from './note-actions';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import NoteEditor from './NoteEditor.svelte';
  import NoteBrowser from './NoteBrowser.svelte';
  import { notesRequest, noteTitle, saveExport, type Note } from './api';
  import { Autosave, draftJournal, readDrafts } from './autosave';
  import './notes.css';

  const mac = /Mac/.test(navigator.platform);
  const mod = mac ? '⌘' : 'Ctrl';
  let note = $state.raw<Note>();
  let editor = $state.raw<Editor>();
  let autosave: Autosave | undefined;
  let status = $state('Saved');
  let error = $state('');
  let busy = $state(false);
  let invalid = $state(false);
  let actions = $state(false);
  let browse = $state(false);
  let browseDeleted = $state(false);
  let preview = $state.raw<Note>();
  let previewError = $state('');
  let browseAnchor = $state<HTMLDivElement>();
  let browseTrigger: HTMLButtonElement;
  const browseId = $props.id();
  let findOpen = $state(false);
  let renaming = $state(false);
  let titleSelection = $state<'all' | 'end'>('all');
  let titleReturnFocus: HTMLElement | undefined;
  let operations: Promise<void> = Promise.resolve();
  $effect(() => {
    editor?.setEditable(!busy && !invalid && !browse, false);
  });
  function report(e: unknown) {
    error = String(e);
  }
  function run(operation: () => Promise<void>) {
    operations = operations.then(async () => {
      busy = true;
      error = '';
      try {
        await operation();
      } catch (e) {
        report(e);
      } finally {
        busy = false;
      }
    });
    return operations;
  }
  async function flush() {
    await autosave?.flush();
  }
  function attach(next: Note) {
    preview = undefined;
    previewError = '';
    autosave?.dispose();
    if (note?.id !== next.id) editor = undefined;
    else if (
      editor &&
      JSON.stringify(editor.getJSON()) !== JSON.stringify(next.document)
    )
      editor.commands.setContent(next.document, { emitUpdate: false });
    invalid = false;
    note = next;
    renaming = false;
    titleReturnFocus = undefined;
    status = 'Saved';
    autosave = new Autosave(
      next,
      (draft) => notesRequest<Note>('save', { ...draft }),
      draftJournal,
      (state, message) => {
        status =
          state === 'saving'
            ? 'Saving…'
            : state === 'saved'
              ? 'Saved'
              : 'Not saved';
        if (message) error = message;
      },
    );
  }
  async function select(id: string) {
    await flush();
    const next = await notesRequest<Note>('get', { id });
    if (next.deleted)
      throw new Error('This note is in Trash. Restore it from Browse Notes.');
    attach(next);
    browse = false;
    findOpen = false;
  }
  async function create() {
    await flush();
    attach(await notesRequest<Note>('create'));
    browse = false;
    findOpen = false;
    titleSelection = 'end';
    renaming = true;
  }
  function changed(document: JSONContent, text: string) {
    if (!note || invalid) return;
    note = { ...note, document, text };
    autosave?.update(note);
  }
  function rename(title: string) {
    if (!note) return;
    note = { ...note, title };
    autosave?.update(note);
  }
  async function recover() {
    for (const draft of readDrafts()) {
      const stored = await notesRequest<Note>('get', { id: draft.id });
      if (
        stored.title === draft.title &&
        JSON.stringify(stored.document) === JSON.stringify(draft.document)
      ) {
        draftJournal.clear(draft.id);
        continue;
      }
      if (!stored.deleted && stored.revision === draft.revision)
        await notesRequest('save', { ...draft });
      else
        await notesRequest('create', {
          title: `${draft.title || 'Untitled note'} (recovered)`,
          document: draft.document,
        });
      draftJournal.clear(draft.id);
    }
  }
  let browseRequested = false;
  async function requested(initial = false) {
    const showBrowser =
      isTauri() && (await notesRequest<boolean>('takeBrowseRequest'));
    if (showBrowser) browseRequested = true;
    try {
      const request = await notesRequest<{
        id: string;
        created: boolean;
      } | null>('takeRequest');
      if (request) {
        await select(request.id);
        if (request.created) {
          titleSelection = 'end';
          renaming = true;
        }
        return;
      }
      if (!initial) return;
      const params = new URLSearchParams(location.search);
      if (params.has('new')) {
        await create();
        return;
      }
      if (params.get('note')) {
        await select(params.get('note')!);
        return;
      }
      const last = await notesRequest<string | null>('lastNote');
      const notes = await notesRequest<Note[]>('search');
      const chosen = notes.find((n) => n.id === last) ?? notes[0];
      if (chosen) await select(chosen.id);
      else await create();
    } finally {
      if (browseRequested && note) {
        browse = true;
        browseRequested = false;
      }
    }
  }
  onMount(() => {
    let disposed = false;
    const stops: (() => void)[] = [];
    const start = async () => {
      if (isTauri()) {
        for (const [event, callback] of [
          ['notes-open', () => void run(() => requested())],
          ['notes-close', () => void run(close)],
        ] as const) {
          const stop = await listen(event, callback);
          if (disposed) stop();
          else stops.push(stop);
        }
      }
      if (disposed) return;
      await run(async () => {
        await recover();
        await requested(true);
      });
    };
    void start().catch(report);
    return () => {
      disposed = true;
      stops.forEach((stop) => stop());
      void flush().catch(() => {});
      autosave?.dispose();
    };
  });
  async function close() {
    await flush();
    await notesRequest('hide');
  }
  async function openBrowser(deleted = false) {
    await flush();
    actions = false;
    preview = undefined;
    previewError = '';
    browseDeleted = deleted;
    browse = true;
  }
  function closeBrowser(restoreFocus = false) {
    browse = false;
    preview = undefined;
    previewError = '';
    if (restoreFocus)
      editor?.commands.focus(undefined, { scrollIntoView: false });
  }
  async function chooseNote(id: string) {
    if (browseDeleted) await notesRequest('restore', { id });
    await select(id);
    await tick();
    editor?.commands.focus();
  }
  function closeActions() {
    actions = false;
    editor?.commands.focus();
  }
  function action(operation: () => Promise<void>) {
    actions = false;
    void run(operation);
  }
  async function duplicate() {
    await flush();
    if (note)
      attach(
        await notesRequest<Note>('create', {
          title: `${noteTitle(note)} copy`,
          document: note.document,
        }),
      );
  }
  async function pin() {
    await flush();
    if (note) {
      const next = await notesRequest<Note>('pin', {
        id: note.id,
        value: !note.pinned,
      });
      await select(next.id);
    }
  }
  async function trash() {
    await flush();
    if (!note) return;
    await notesRequest('trash', { id: note.id });
    autosave?.dispose();
    autosave = undefined;
    note = undefined;
    editor = undefined;
    const remaining = await notesRequest<Note[]>('search');
    if (remaining[0]) await select(remaining[0].id);
    else await openBrowser();
  }
  async function copy(format: 'text' | 'html' | 'link') {
    await flush();
    if (!note || !editor) return;
    const contents =
      format === 'link'
        ? `tooki://notes/${note.id}`
        : format === 'html'
          ? editor.getHTML()
          : editor.getText();
    if (isTauri()) await writeText(contents);
    else await navigator.clipboard.writeText(contents);
    status = 'Copied';
  }
  async function exportNote(format: 'txt' | 'html' | 'json') {
    await flush();
    if (!note || !editor) return;
    const contents =
      format === 'txt'
        ? editor.getText()
        : format === 'html'
          ? `<!doctype html><html><head><meta charset="utf-8"><title>Note</title></head><body>${editor.getHTML()}</body></html>`
          : JSON.stringify(
              { title: note.title, document: note.document },
              null,
              2,
            );
    if (await saveExport(contents, format)) status = 'Exported';
  }
  let menu = $derived(
    noteActions(
      note,
      mod,
      (command) => {
        actions = false;
        if (command === 'browse' || command === 'browse-trash') {
          void run(() => openBrowser(command === 'browse-trash'));
          return;
        }
        if (command === 'keep-top') {
          setPreference('notesKeepOnTop', !preferences.notesKeepOnTop);
          return;
        }
        if (command === 'settings') {
          void invoke('open_settings', { page: 'notes' }).catch(report);
          return;
        }
        if (command === 'rename') {
          titleReturnFocus = undefined;
          titleSelection = 'end';
          renaming = true;
          return;
        }
        if (command === 'find') {
          findOpen = true;
          return;
        }
        const operations = {
          new: create,
          duplicate,
          pin,
          trash,
          'copy-text': () => copy('text'),
          'copy-html': () => copy('html'),
          deeplink: () => copy('link'),
          'export-text': () => exportNote('txt'),
          'export-html': () => exportNote('html'),
          'export-json': () => exportNote('json'),
        };
        void run(operations[command]);
      },
      preferences.notesKeepOnTop,
    ),
  );
  function captureShortcut(event: KeyboardEvent) {
    if (
      event.ctrlKey &&
      !event.metaKey &&
      !event.altKey &&
      !event.shiftKey &&
      event.key.toLowerCase() === 'x' &&
      !event.isComposing &&
      !document.querySelector('dialog[open]') &&
      !browse
    ) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (event.repeat || busy || !note || invalid) return;
      if (renaming && document.activeElement instanceof HTMLElement)
        document.activeElement.blur();
      action(trash);
      return;
    }
    if (
      renaming &&
      (mac ? event.metaKey : event.ctrlKey) &&
      !event.altKey &&
      !event.shiftKey &&
      event.key.toLowerCase() === 'p' &&
      !event.isComposing &&
      !document.querySelector('dialog[open]')
    ) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (event.repeat || busy) return;
      // Commit the title before Browse Notes reads the saved list.
      if (document.activeElement instanceof HTMLElement)
        document.activeElement.blur();
      keyboard(event);
      return;
    }
    void titleShortcut(event);
  }
  async function titleShortcut(event: KeyboardEvent) {
    if (
      !(mac ? event.metaKey : event.ctrlKey) ||
      event.altKey ||
      event.shiftKey ||
      event.key.toLowerCase() !== 'r' ||
      event.isComposing ||
      document.querySelector('dialog[open]') ||
      browse ||
      actions
    )
      return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (event.repeat || busy || !note || !editor || invalid) return;
    if (renaming) {
      const previous = titleReturnFocus;
      // Blurring commits the shared rename input before restoring focus.
      if (document.activeElement instanceof HTMLElement)
        document.activeElement.blur();
      renaming = false;
      titleReturnFocus = undefined;
      await tick();
      if (previous?.isConnected && !editor.view.dom.contains(previous)) {
        previous.focus({ preventScroll: true });
      } else {
        // ProseMirror retains the exact selection while its editor is blurred.
        editor.commands.focus(undefined, { scrollIntoView: false });
      }
    } else {
      titleReturnFocus =
        document.activeElement instanceof HTMLElement
          ? document.activeElement
          : undefined;
      titleSelection = 'end';
      renaming = true;
    }
  }
  function keyboard(event: KeyboardEvent) {
    if (event.isComposing || document.querySelector('dialog[open]')) return;
    if ((event.metaKey || event.ctrlKey) && event.key === ',') {
      event.preventDefault();
      void invoke('open_settings', { page: 'notes' }).catch(report);
      return;
    }
    if (event.key === 'Escape' && actions) {
      event.preventDefault();
      closeActions();
      return;
    }
    if (!(mac ? event.metaKey : event.ctrlKey) || event.altKey) return;
    const key = event.key.toLowerCase();
    if (['n', 'd', 'p', 'k', 'f', 'w', 's'].includes(key)) {
      event.preventDefault();
      event.stopPropagation();
      if (busy) return;
      if (key === 'n') action(create);
      else if (key === 'd') action(duplicate);
      else if (key === 'p' && event.shiftKey) action(pin);
      else if (key === 'p') {
        if (browse) closeBrowser(true);
        else void run(openBrowser);
      } else if (key === 'k') {
        actions = !actions;
      } else if (key === 'f') {
        actions = false;
        findOpen = true;
      } else if (key === 'w') void run(close);
      else if (key === 's') void run(flush);
    }
  }
</script>

<svelte:window
  onkeydowncapture={captureShortcut}
  onkeydown={keyboard}
  onblur={() => {
    void flush().catch(report);
  }}
/>
<FloatingSurface
  class="notes-window"
  label="Notes"
  keepOnTop={preferences.notesKeepOnTop}
>
  <header class="note-header" data-tauri-drag-region>
    {#if renaming && note}<RenameInput
        label="Note title"
        selection={titleSelection}
        onnext={() => editor?.commands.focus()}
        maxlength={200}
        value={note.title}
        oncommit={(title) => {
          rename(title);
          renaming = false;
          titleReturnFocus = undefined;
        }}
        oncancel={() => {
          renaming = false;
          titleReturnFocus = undefined;
        }}
      />
    {:else}<button
        class="note-title"
        disabled={!note || busy}
        title="Rename note"
        onclick={() => {
          titleSelection = 'all';
          renaming = true;
        }}>{note ? noteTitle(note) : 'Notes'}</button
      >{/if}
    <div class="note-header-actions footer-actions">
      <SaveIndicator {status} onretry={() => void run(flush)} />
      <div class="filter-control" bind:this={browseAnchor}>
        <WindowControlGroup label="Notes controls">
          <button
            bind:this={browseTrigger}
            aria-label="Browse notes"
            title={`Browse notes (${mod} P)`}
            aria-pressed={browse}
            aria-haspopup="dialog"
            aria-expanded={browse}
            aria-controls={browseId}
            disabled={busy}
            onclick={() =>
              browse ? closeBrowser(true) : void run(openBrowser)}
            ><PanelsTopLeft size={12} /></button
          >
          <button
            aria-label="New note"
            title={`New note (${mod} N)`}
            disabled={busy}
            onclick={() => void run(create)}><Plus size={14} /></button
          >
        </WindowControlGroup>
        {#if browse && browseAnchor}<NoteBrowser
            id={browseId}
            anchor={browseAnchor}
            value={note?.id ?? ''}
            deleted={browseDeleted}
            onchoose={(id) => void run(() => chooseNote(id))}
            onpreview={(next) => {
              if (!browse || busy) return;
              preview = next;
              previewError = '';
            }}
            onclose={closeBrowser}
          />{/if}
      </div>
      <button
        class="floating-round"
        aria-label="Actions"
        title={`Actions (${mod} K)`}
        aria-expanded={actions}
        disabled={busy}
        onclick={() => {
          actions = !actions;
          browse = false;
        }}><Ellipsis size={12} /></button
      >
      <button
        class="floating-round"
        aria-label="Hide notes"
        title="Hide notes"
        disabled={busy}
        onclick={() => void run(close)}><Minus size={12} /></button
      >
    </div>
  </header>
  {#if error}<div class="note-error" role="alert">
      <CircleAlert size={15} /><span>{error}</span
      >{#if status === 'Not saved'}<button
          class="note-text-button"
          onclick={() => void run(flush)}>Retry</button
        >{/if}
    </div>{/if}
  <div
    class="note-body"
    class:preview-hidden={browse && !!preview && preview.id !== note?.id}
  >
    {#if note}
      {#key note.id}<NoteEditor
          document={note.document}
          onchange={changed}
          onready={(value) => {
            editor = value;
            void tick().then(() => {
              if (!renaming && !browse) value.commands.focus('end');
            });
          }}
          ontitle={() => {
            titleSelection = 'end';
            renaming = true;
          }}
          onerror={(message) => {
            invalid = true;
            error = message;
          }}
          bind:findOpen
        />{/key}
    {:else}<div class="note-empty">
        <h1>A little room for your thoughts.</h1>
        <button
          class="note-text-button"
          disabled={busy}
          onclick={() => void run(create)}
          ><Plus size={16} />Create a note</button
        >
      </div>{/if}
  </div>
  {#if browse && preview && preview.id !== note?.id}
    <div class="note-body">
      {#if previewError}<p class="note-error" role="alert">
          {previewError}
        </p>{/if}
      {#key preview.id}<NoteEditor
          document={preview.document}
          readonly
          onchange={() => {}}
          onready={() => {}}
          ontitle={() => {}}
          onerror={(message) => (previewError = message)}
        />{/key}
    </div>
  {/if}
  {#if actions}<PopupSurface title="Note actions" onclose={closeActions}
      ><ActionsMenu actions={menu} /></PopupSurface
    >{/if}
</FloatingSurface>

<style>
  .note-body {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
  }
  .preview-hidden {
    display: none;
  }
</style>
