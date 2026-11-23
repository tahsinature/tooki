import { invoke, isTauri } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import type { Item } from '../../lib/data';
type Application = { id: string; name: string; icon?: string };
export const applicationCatalog = $state({
  items: [] as Item[],
  error: '',
  refreshing: false,
  completedRefreshes: 0,
});
function update(apps: Application[]) {
  applicationCatalog.items = apps.map((app) => ({
    id: `app:${app.id}`,
    title: app.name,
    subtitle: app.id,
    icon: app.icon,
    kind: 'application',
    group: 'Applications',
    content: '',
    source: '',
    time: '',
  }));
  applicationCatalog.error = '';
}
export async function refreshApplications() {
  if (!isTauri()) return;
  try {
    update(await invoke<Application[]>('list_applications'));
  } catch (error) {
    applicationCatalog.error = String(error);
  }
}
export function observeApplications() {
  let disposed = false;
  const stops: (() => void)[] = [];
  async function start() {
    for (const subscription of [
      listen<boolean>(
        'applications-refreshing',
        (event) => {
          applicationCatalog.refreshing = event.payload;
          if (!event.payload) applicationCatalog.completedRefreshes++;
        },
      ),
      listen<Application[]>('applications-changed', (event) =>
        update(event.payload),
      ),
      listen<string>(
        'applications-error',
        (event) => (applicationCatalog.error = event.payload),
      ),
    ]) {
      const stop = await subscription;
      if (disposed) stop();
      else stops.push(stop);
    }
    if (!disposed) await refreshApplications();
  }
  if (isTauri())
    void start().catch((error) => (applicationCatalog.error = String(error)));
  return () => {
    disposed = true;
    stops.forEach((stop) => stop());
  };
}
