<script lang="ts">
  import {
    Plus,
    FolderOpen,
    Eye,
    Copy,
    Trash2,
    Pencil,
    ExternalLink,
    ClipboardPaste,
    PanelTop,
  } from '@lucide/svelte';
  import PopupSurface from '../../components/PopupSurface.svelte';
  import ActionsMenu from '../../components/ActionsMenu.svelte';
  import type { Shelf, ShelfItem, Library } from './api';
  import type { Item } from '../../lib/data';
  let {
    shelf,
    row,
    current,
    apps,
    capabilities,
    canConvert = false,
    open,
    perform,
    edit,
    onclose,
  }: {
    shelf: Shelf | undefined;
    row: Item | undefined;
    current: ShelfItem | undefined;
    apps: { name: string; path: string; isDefault: boolean }[] | null;
    capabilities: Library['capabilities'];
    canConvert?: boolean;
    open: () => void;
    perform: (
      operation: string,
      args?: Record<string, unknown>,
    ) => Promise<void>;
    edit: (operation: string) => void;
    onclose: () => void;
  } = $props();
</script>

<PopupSurface title="Shelf Actions" {onclose}>
  <ActionsMenu
    actions={apps
      ? apps.map((app) => ({
          id: app.path,
          label: app.name,
          icon: ExternalLink,
          run: () => void perform('open', { app: app.path }),
        }))
      : [
          ...(!shelf && row
            ? [
                {
                  id: 'browse',
                  label: 'Open Shelf',
                  icon: FolderOpen,
                  run: open,
                },
                {
                  id: 'show',
                  label: 'Show Floating Shelf',
                  icon: PanelTop,
                  run: () => void perform('show'),
                },
              ]
            : []),
          {
            id: 'new',
            label: 'New Shelf',
            icon: Plus,
            shortcut: '⌘ N',
            run: () => edit('create'),
          },
          ...(shelf
            ? [
                {
                  id: 'files',
                  label: 'Add File References…',
                  icon: Plus,
                  run: () => void perform('choose', { copy: false }),
                },
                {
                  id: 'copies',
                  label: 'Add File Copies…',
                  icon: Copy,
                  run: () => void perform('choose', { copy: true }),
                },
                {
                  id: 'paste',
                  label: 'Paste from Clipboard',
                  icon: ClipboardPaste,
                  run: () => void perform('paste'),
                },
                {
                  id: 'float',
                  label: 'Show Floating Shelf',
                  icon: PanelTop,
                  run: () => void perform('show'),
                },
              ]
            : []),
          ...(current
            ? [
                {
                  id: 'open',
                  label: 'Open',
                  icon: ExternalLink,
                  run: () => void perform('open'),
                },
                ...(capabilities.nativePreview
                  ? [
                      {
                        id: 'preview',
                        label: 'Quick Look',
                        icon: Eye,
                        run: () => void perform('preview'),
                      },
                    ]
                  : []),
                ...(capabilities.openWith
                  ? [
                      {
                        id: 'apps',
                        label: 'Open With…',
                        icon: ExternalLink,
                        run: () => void perform('apps'),
                      },
                    ]
                  : []),
                ...(capabilities.copyFiles
                  ? [
                      {
                        id: 'copyfile',
                        label: 'Copy File',
                        icon: Copy,
                        run: () => void perform('copyFile'),
                      },
                    ]
                  : []),
                {
                  id: 'reveal',
                  label: 'Show in File Manager',
                  icon: FolderOpen,
                  run: () => void perform('reveal'),
                },
                {
                  id: 'path',
                  label: 'Copy Path',
                  icon: Copy,
                  run: () => void perform('copyPath'),
                },
                {
                  id: 'drag',
                  label: 'Drag Copy',
                  icon: Copy,
                  run: () => void perform('drag'),
                },
              ]
            : []),
          ...(current &&
          canConvert &&
          /\.(png|jpe?g|heic|heif|tiff?|gif|bmp|webp)$/i.test(current.path)
            ? [
                {
                  id: 'convert',
                  label: 'Convert Image…',
                  icon: Eye,
                  run: () => void perform('convert'),
                },
              ]
            : []),
          ...(row
            ? [
                {
                  id: 'rename',
                  label: shelf ? 'Rename File…' : 'Rename Shelf…',
                  icon: Pencil,
                  run: () => edit(shelf ? 'renameItem' : 'renameShelf'),
                },
                {
                  id: 'remove',
                  label: shelf ? 'Remove from Shelf…' : 'Delete Shelf…',
                  destructive: true,
                  icon: Trash2,
                  run: () => edit(shelf ? 'remove' : 'deleteShelf'),
                },
              ]
            : []),
        ]}
  />
</PopupSurface>
