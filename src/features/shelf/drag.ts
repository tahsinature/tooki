import { startDrag } from '@crabnebula/tauri-plugin-drag';
import { request } from './api';
/** Both Shelf surfaces share native drop completion and snapshot the dragged item ids. */
export async function dragShelfItems(
  shelf: string,
  item: string | string[] | undefined,
  onerror: (message: string) => void,
) {
  if (/Mac/i.test(navigator.platform)) {
    await request('nativeDrag', {
      shelf,
      items: Array.isArray(item) ? item : item ? [item] : undefined,
    });
    return;
  }
  const data = await request<{
    path?: string;
    paths?: string[];
    items: string[];
    icon: string;
  }>(Array.isArray(item) ? 'dragAll' : item ? 'drag' : 'dragAll', {
    shelf,
    item: Array.isArray(item) ? undefined : item,
    items: Array.isArray(item) ? item : undefined,
  });
  await startDrag(
    { item: data.paths ?? [data.path!], icon: data.icon, mode: 'copy' },
    (event) => {
      void request('finishDrag', {
        shelf,
        items: data.items,
        dropped: event.result === 'Dropped',
      }).catch((e) => onerror(String(e)));
    },
  );
}
