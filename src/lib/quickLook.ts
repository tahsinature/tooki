import { invoke, isTauri } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

type PreviewNavigation = {
  context: string;
  direction: number;
  extend: boolean;
};

/** Native events are window-targeted; the context separates views within that window. */
export function watchQuickLook(
  context: string,
  navigate: (direction: number, extend: boolean) => void,
): () => void {
  if (!isTauri() || !context) return () => {};
  let disposed = false;
  let unlisten: (() => void) | undefined;
  void listen<PreviewNavigation>('quick-look-navigation', ({ payload }) => {
    if (!disposed && payload.context === context)
      navigate(payload.direction, payload.extend);
  })
    .then((stop) => {
      if (disposed) stop();
      else unlisten = stop;
    })
    .catch((error) => console.error('Quick Look navigation:', error));
  return () => {
    disposed = true;
    unlisten?.();
    void invoke('close_preview', { context }).catch(() => {});
  };
}

export function closeQuickLook(context: string): Promise<unknown> {
  return isTauri() ? invoke('close_preview', { context }) : Promise.resolve();
}
