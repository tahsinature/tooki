import { invoke } from '@tauri-apps/api/core';
import type { Item } from '../../lib/data';
export type Clip = {
  id: string;
  kind: 'text' | 'link' | 'image' | 'file' | 'color';
  title: string;
  content: string;
  files: string[];
  image: string;
  width: number;
  height: number;
  bytes: number;
  source: string;
  sourceId: string;
  copiedAt: number;
  firstCopiedAt: number;
  copies: number;
  pinned: boolean;
  ocr: string;
  ocrState: string;
  missingFiles: string[];
};
export type ClipboardSettings = {
  enabled: boolean;
  persistHistory: boolean;
  maxItems: number;
  maxImages: number;
  retentionDays: number;
  ocrEnabled: boolean;
  ignoredApps: string[];
};
export function request<T = void>(
  operation: string,
  args: object = {},
): Promise<T> {
  return invoke<T>('clipboard_request', { operation, args });
}
export function dateGroup(time: number, today = new Date()): string {
  const midnight = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  ).getTime();
  if (time >= midnight) return 'Today';
  const yesterday = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate() - 1,
  ).getTime();
  if (time >= yesterday) return 'Yesterday';
  const week = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate() - 7,
  ).getTime();
  return time >= week ? 'This Week' : 'Older';
}
export function row(clip: Clip): Item {
  return {
    ...clip,
    subtitle: clip.source,
    group: dateGroup(clip.copiedAt),
    time: new Date(clip.copiedAt).toLocaleString(),
  };
}
