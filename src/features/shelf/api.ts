import { invoke } from '@tauri-apps/api/core';
export type ShelfItem = {
  id: string;
  name: string;
  path: string;
  owned: boolean;
  originalPath: string | null;
};
export type Shelf = { id: string; name: string; items: ShelfItem[] };
export type Library = {
  imageConversion?: boolean;
  shelves: Shelf[];
  settings: {
    enabled: boolean;
    showOnShiftDrag: boolean;
    removeAfterDragOut: boolean;
  };
  shelfCapabilities: { shiftDrag: boolean; shiftDragReason: string };
  capabilities: {
    nativePreview: boolean;
    openWith: boolean;
    copyFiles: boolean;
  };
};
export function request<T = void>(
  operation: string,
  args: Record<string, unknown> = {},
) {
  return invoke<T>('shelf_request', { operation, args });
}
