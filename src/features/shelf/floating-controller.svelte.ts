import { invoke } from '@tauri-apps/api/core';
import { tick } from 'svelte';
import { closeQuickLook, watchQuickLook } from '../../lib/quickLook';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { request, type Shelf, type Library } from './api';
import { dragShelfItems } from './drag';
import { emptySelection, selectItem } from './selection';
import { showShelfMenu } from './native-menu';
import { showItemMenu } from './item-menu';

export class FloatingShelfController {
  shelf = $state<Shelf>({ id: '', name: 'Shelf', items: [] });
  capabilities = $state<Library['capabilities']>({
    nativePreview: false,
    openWith: false,
    copyFiles: false,
  });
  selection = $state(emptySelection());
  expanded = $state(false);
  conversion = $state<string[]>([]);
  canConvert = $state(false);
  detail = $state(false);
  detailHeight = $state(202);
  previews = $state<Record<string, string>>({});
  metadata = $state<{ text?: string; bytes?: number; exists?: boolean }>({});
  keepOnTop = $state(false);
  editing = $state<'shelf' | 'item' | ''>('');
  name = $state('');
  armed = $state('');
  holding = $state(false);
  option = $state(false);
  leaving = $state(false);
  error = $state('');
  bytes = $state(0);
  itemBytes = $state<Record<string, number>>({});
  drop = $state<'original' | 'copy' | 'content' | ''>('');
  busy = $state(false);
  importing = $state<{ done: number; total: number } | null>(null);
  private generation = 0;
  private disposed = false;
  private stops: (() => void)[] = [];
  private timers: ReturnType<typeof setTimeout>[] = [];
  private escapeDown = false;
  private escapeHeld = false;
  private escapeGeneration = 0;
  private stopGesture = () => {};
  constructor(readonly id: string) {
    this.shelf.id = id;
  }
  get selectedItems() {
    return this.shelf.items.filter((item) =>
      this.selection.ids.includes(item.id),
    );
  }
  get current() {
    return this.shelf.items.find((item) => item.id === this.selection.cursor);
  }
  get recent() {
    return this.shelf.items.slice(-3);
  }
  async mount() {
    this.stops.push(
      watchQuickLook(`shelf:${this.id}`, (direction, extend) => {
        void this.moveSelection(direction, extend);
      }),
    );
    await this.load();
    for (const [name, callback, target] of [
      ['shelf-changed', () => void this.load(), undefined],
      [
        'shelf-import-progress',
        (event: any) => (this.importing = event.payload),
        getCurrentWindow().label,
      ],
      [
        'shelf-error',
        (event: any) => (this.error = String(event.payload)),
        getCurrentWindow().label,
      ],
      [
        'shelf-drop-state',
        (event: any) => (this.drop = event.payload),
        getCurrentWindow().label,
      ],
      [
        'shelf-modifiers',
        (event: any) => (this.option = event.payload.option),
        undefined,
      ],
    ] as const) {
      // Unscoped listeners also receive events emitted to other windows.
      const stop = await listen(name, callback, { target });
      if (this.disposed) stop();
      else this.stops.push(stop);
    }
  }
  dispose() {
    this.disposed = true;
    this.generation++;
    this.escapeGeneration++;
    this.stopGesture();
    this.stops.forEach((stop) => stop());
    this.timers.forEach(clearTimeout);
  }
  async load() {
    const generation = ++this.generation;
    try {
      const data = await request<Library>('list');
      if (this.disposed || generation !== this.generation) return;
      const shelf = data.shelves.find((s) => s.id === this.id);
      if (!shelf) return;
      this.shelf = shelf;
      this.capabilities = data.capabilities;
      this.canConvert = !!data.imageConversion;
      this.selection = {
        ...this.selection,
        ids: this.selection.ids.filter((id) =>
          shelf.items.some((item) => item.id === id),
        ),
      };
      const summary = await request<{
        bytes: number;
        items: { id: string; bytes: number }[];
      }>('summary', { shelf: this.id });
      if (this.disposed || generation !== this.generation) return;
      this.bytes = summary.bytes;
      this.itemBytes = Object.fromEntries(
        summary.items.map((item) => [item.id, item.bytes]),
      );
      if (!shelf.items.length) {
        this.expanded = false;
        this.detail = false;
      }
      void this.loadThumbnails(shelf, generation);
    } catch (e) {
      this.error = String(e);
    }
  }
  private async loadThumbnails(shelf: Shelf, generation: number) {
    try {
      // Limit native work to visible rows; cache successful thumbnails by identity and path.
      for (const item of shelf.items.slice(-100)) {
        if (this.previews[item.path]) continue;
        const image = await request<string | null>('thumbnail', {
          shelf: this.id,
          item: item.id,
        });
        if (this.disposed || generation !== this.generation) return;
        if (image) this.previews = { ...this.previews, [item.path]: image };
      }
    } catch (e) {
      this.error = String(e);
    }
  }
  async refreshConvertedFiles() {
    this.previews = {};
    await this.load();
  }
  async resize() {
    const height = this.conversion.length
      ? 390
      : this.editing === 'item'
        ? 210
        : this.detail
          ? Math.min(500, 78 + this.detailHeight)
          : this.drop
            ? Math.max(
                150,
                this.expanded
                  ? Math.min(376, 88 + this.shelf.items.length * 32)
                  : 160,
              )
            : this.expanded && this.shelf.items.length
              ? Math.min(376, 88 + this.shelf.items.length * 32)
              : this.shelf.items.length
                ? 160
                : 150;
    try {
      await invoke('resize_utility_window', {
        width: 300,
        height,
        animate: !matchMedia('(prefers-reduced-motion: reduce)').matches,
      });
    } catch (e) {
      this.error = String(e);
    }
  }
  async act(operation: string, args: Record<string, unknown> = {}) {
    this.busy = true;
    this.error = '';
    try {
      await request(operation, {
        shelf: this.id,
        item: this.selection.cursor,
        ...args,
      });
      await this.load();
    } catch (e) {
      this.error = String(e);
    } finally {
      this.busy = false;
    }
  }
  async runSelection(action: string, args: Record<string, unknown> = {}) {
    const ids = this.selection.ids.length
      ? this.selection.ids
      : this.shelf.items.map((item) => item.id);
    await this.act('selection', { action, items: ids, ...args });
  }
  async select(id: string, shift = false, toggle = false) {
    this.selection = selectItem(
      this.shelf.items.map((item) => item.id),
      this.selection,
      id,
      shift,
      toggle,
    );
    if (this.capabilities.nativePreview) {
      void request('previewUpdate', {
        shelf: this.id,
        items: this.selection.ids,
      }).catch((e) => (this.error = String(e)));
    }
    if (this.detail) await this.showDetail();
    await tick();
    document
      .querySelector(`[data-shelf-item="${id}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  }
  async moveSelection(direction: number, extend = false) {
    const order = this.shelf.items.map((item) => item.id);
    if (!order.length) return;
    const index = !this.selection.ids.length
      ? direction > 0
        ? 0
        : order.length - 1
      : Math.max(
          0,
          Math.min(
            order.length - 1,
            order.indexOf(this.selection.cursor) + direction,
          ),
        );
    await this.select(order[index], extend);
  }
  async showDetail() {
    if (!this.current) return;
    this.detail = true;
    try {
      this.metadata = await request('detail', {
        shelf: this.id,
        item: this.current.id,
      });
    } catch (e) {
      this.error = String(e);
    }
  }
  async hide() {
    await closeQuickLook(`shelf:${this.id}`).catch(
      (e) => (this.error = String(e)),
    );
    this.leaving = true;
    this.timers.push(
      setTimeout(() => {
        void getCurrentWindow().hide();
        this.leaving = false;
      }, 180),
    );
  }
  async destructive(operation: string) {
    if (
      this.shelf.items.some((item) => item.owned) &&
      this.armed !== operation
    ) {
      this.armed = operation;
      this.timers.push(setTimeout(() => (this.armed = ''), 4000));
      return;
    }
    this.armed = '';
    await this.act(operation);
  }
  edit(kind: 'shelf' | 'item') {
    this.editing = kind;
    this.name = kind === 'shelf' ? this.shelf.name : (this.current?.name ?? '');
    if (kind === 'item')
      void tick().then(() => {
        const input = document.querySelector<HTMLInputElement>(
          '[data-shelf-rename]',
        );
        input?.focus();
        input?.select();
      });
  }
  async saveName() {
    const kind = this.editing;
    if (!kind) return;
    this.editing = '';
    await this.act(kind === 'shelf' ? 'renameShelf' : 'renameItem', {
      name: this.name,
    });
  }
  async menu(event?: MouseEvent) {
    const rect = (
      event?.currentTarget as HTMLElement | undefined
    )?.getBoundingClientRect();
    try {
      await showShelfMenu(
        [
          {
            text: this.keepOnTop ? 'Stop Keeping on Top' : 'Keep on Top',
            action: () => {
              this.keepOnTop = !this.keepOnTop;
            },
          },
          { text: 'Rename…', action: () => this.edit('shelf') },
          ...(this.shelf.items.length
            ? [
                {
                  text: navigator.platform.includes('Mac')
                    ? 'Show All in Finder'
                    : 'Show All in File Manager',
                  action: () => void this.act('revealAll'),
                },
                {
                  text: 'Copy All Paths',
                  action: () => void this.act('copyPaths'),
                },
                { item: 'Separator' as const },
                { text: 'Clear', action: () => void this.destructive('clear') },
              ]
            : []),
          {
            text: 'Delete Shelf',
            action: () => void this.destructive('deleteShelf'),
          },
        ],
        rect ? { x: rect.left, y: rect.bottom + 3 } : undefined,
      );
    } catch (e) {
      this.error = String(e);
    }
  }
  async context(event: MouseEvent, id?: string) {
    event.preventDefault();
    if (id && !this.selection.ids.includes(id)) await this.select(id);
    const items = this.selectedItems.length
      ? this.selectedItems
      : this.shelf.items;
    try {
      await showItemMenu(
        this.id,
        items,
        this.capabilities,
        (action, args) => void this.runSelection(action, args),
        () => this.edit('item'),
        { x: event.clientX, y: event.clientY },
        this.canConvert &&
          items.every((item) =>
            /\.(png|jpe?g|heic|heif|tiff?|gif|bmp|webp)$/i.test(item.path),
          )
          ? () => (this.conversion = items.map((item) => item.id))
          : undefined,
      );
    } catch (e) {
      this.error = String(e);
    }
  }
  gesture(event: PointerEvent, id?: string) {
    if (event.button !== 0) return;
    this.stopGesture();
    const x = event.clientX,
      y = event.clientY;
    const stop = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', stop);
    };
    const move = (e: PointerEvent) => {
      if (Math.hypot(e.clientX - x, e.clientY - y) < 6) return;
      stop();
      const items = id
        ? this.selection.ids.includes(id)
          ? this.selection.ids
          : [id]
        : undefined;
      void dragShelfItems(
        this.id,
        items,
        (message) => (this.error = message),
      ).catch((e) => (this.error = String(e)));
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', stop, { once: true });
    this.stopGesture = stop;
  }
  blur() {
    this.escapeGeneration++;
    this.escapeDown = false;
    this.holding = false;
    this.option = false;
  }
  keyup(event: KeyboardEvent) {
    this.option = event.altKey;
    if (event.key !== 'Escape' || !this.escapeDown) return;
    this.escapeGeneration++;
    this.escapeDown = false;
    if (this.holding || this.escapeHeld) {
      this.holding = false;
      return;
    }
    if (this.armed) this.armed = '';
    else if (this.detail) this.detail = false;
    else if (this.expanded) this.expanded = false;
    else void this.hide();
  }
  keyboard(event: KeyboardEvent) {
    this.option = event.altKey;
    if (
      event.defaultPrevented ||
      event.isComposing ||
      this.editing ||
      this.conversion.length
    )
      return;
    const cmd = event.metaKey || event.ctrlKey,
      key = event.key.toLowerCase();
    if (event.key === 'Escape') {
      event.preventDefault();
      if (event.repeat) return;
      const generation = ++this.escapeGeneration;
      this.escapeDown = true;
      this.escapeHeld = false;
      this.timers.push(
        setTimeout(() => {
          if (!this.escapeDown || generation !== this.escapeGeneration) return;
          this.holding = true;
          this.escapeHeld = true;
          this.timers.push(
            setTimeout(() => {
              if (!this.escapeDown || generation !== this.escapeGeneration)
                return;
              this.escapeDown = false;
              this.holding = false;
              void this.destructive('deleteShelf');
            }, 1000),
          );
        }, 250),
      );
      return;
    }
    const order = this.shelf.items.map((item) => item.id);
    if (cmd && key === 'v') {
      event.preventDefault();
      void this.act('paste');
    } else if (cmd && key === 'a') {
      event.preventDefault();
      this.selection = {
        cursor: order[0] ?? '',
        anchor: order[0] ?? '',
        ids: order,
      };
    } else if (cmd && key === 'n') {
      event.preventDefault();
      void request<string>('create')
        .then((id) => request('show', { shelf: id }))
        .catch((e) => (this.error = String(e)));
    } else if (cmd && key === 'k') {
      event.preventDefault();
      void this.menu();
    } else if (key === ' ' || (cmd && key === 'y')) {
      event.preventDefault();
      void this.runSelection('preview');
    } else if (event.key === 'Enter' && this.armed) {
      event.preventDefault();
      void this.destructive(this.armed);
    } else if (
      !this.expanded &&
      order.length &&
      ['Enter', 'ArrowDown'].includes(event.key)
    ) {
      event.preventDefault();
      this.expanded = true;
      if (event.key === 'ArrowDown') void this.select(order[0]);
    } else if (event.key === 'ArrowRight' && this.expanded && order.length) {
      event.preventDefault();
      if (!this.current)
        this.selection = selectItem(order, this.selection, order[0]);
      void this.showDetail();
    } else if (event.key === 'ArrowLeft' && this.detail) {
      event.preventDefault();
      this.detail = false;
    } else if (['ArrowDown', 'ArrowUp'].includes(event.key) && order.length) {
      event.preventDefault();
      void this.moveSelection(
        event.key === 'ArrowDown' ? 1 : -1,
        event.shiftKey,
      );
    } else if (
      ['Backspace', 'Delete'].includes(event.key) &&
      this.selection.ids.length
    ) {
      event.preventDefault();
      void this.runSelection('remove');
    }
  }
}
