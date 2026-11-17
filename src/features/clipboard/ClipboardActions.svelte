<script lang="ts">
  import {
    Copy,
    ClipboardPaste,
    Pin,
    Trash2,
    Eye,
    ExternalLink,
    FileText,
    ScanText,
  } from '@lucide/svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import type { Clip } from './api';
  let {
    item,
    apps,
    act,
    onclose,
  }: {
    item: Clip;
    apps: { path: string; name: string; isDefault: boolean }[] | null;
    act: (operation: string, mode?: string, app?: string) => Promise<void>;
    onclose: () => void;
  } = $props();
</script>

<PopupSurface title={apps ? 'Open With' : 'Actions'} {onclose}>
  {#if apps}
    <ActionsMenu
      actions={apps.map((app) => ({
        id: app.path,
        label: app.name + (app.isDefault ? ' (Default)' : ''),
        icon: ExternalLink,
        run: () => void act('open', undefined, app.path),
      }))}
    />
    {#if !apps.length}<p>No applications available.</p>{/if}
  {:else}<ActionsMenu
      actions={[
        {
          id: 'copy',
          label: 'Copy',
          icon: Copy,
          shortcut: '↵',
          run: () => void act('copy'),
        },
        {
          id: 'paste',
          label: 'Paste to Previous App',
          icon: ClipboardPaste,
          shortcut: '⌘ ↵',
          run: () => void act('paste'),
        },
        ...(item.kind === 'text' || item.kind === 'link'
          ? [
              {
                id: 'plain',
                label: 'Copy Plain Text',
                icon: FileText,
                run: () => void act('copy', 'plain'),
              },
            ]
          : []),
        ...(item.kind === 'file'
          ? [
              {
                id: 'paths',
                label: 'Copy File Paths',
                icon: FileText,
                run: () => void act('copy', 'paths'),
              },
            ]
          : []),
        ...(item.kind === 'image'
          ? [
              {
                id: 'show-ocr',
                label:
                  item.ocrState === 'pending'
                    ? 'Recognizing text…'
                    : 'Show Recognized Text',
                icon: Eye,
                disabled: item.ocrState !== 'done',
                run: () => void act('preview', 'ocr'),
              },
              {
                id: 'ocr',
                label: 'Copy Recognized Text',
                icon: ScanText,
                disabled: item.ocrState !== 'done',
                run: () => void act('copy', 'ocr'),
              },
              {
                id: 'retry',
                label: 'Recognize Text Again',
                icon: ScanText,
                run: () => void act('retryOcr'),
              },
            ]
          : []),
        {
          id: 'preview',
          label: 'Quick Look',
          icon: Eye,
          shortcut: '⌘ Y',
          run: () => void act('preview'),
        },
        {
          id: 'open',
          label: 'Open With…',
          icon: ExternalLink,
          shortcut: '⌘ O',
          run: () => void act('apps'),
        },
        {
          id: 'pin',
          label: item.pinned ? 'Unpin' : 'Pin',
          icon: Pin,
          shortcut: '⇧ ⌘ P',
          run: () => void act('pin'),
        },
        {
          id: 'delete',
          label: 'Delete',
          icon: Trash2,
          shortcut: '⌃ X',
          run: () => void act('delete'),
        },
      ]}
    />{/if}
</PopupSurface>
