import { showShelfMenu } from './native-menu';
import { request, type ShelfItem, type Library } from './api';
export async function showItemMenu(
  shelf: string,
  items: ShelfItem[],
  capabilities: Library['capabilities'],
  run: (action: string, args?: Record<string, unknown>) => void,
  rename: () => void,
  point: { x: number; y: number },
  convert?: () => void,
) {
  const apps =
    capabilities.openWith && items.length
      ? await request<{ name: string; path: string; isDefault: boolean }[]>(
          'apps',
          { shelf, item: items[0].id },
        )
      : [];
  await showShelfMenu(
    [
      {
        text: 'Quick Look',
        enabled: capabilities.nativePreview,
        action: () => run('preview'),
      },
      { text: 'Open', action: () => run('open') },
      ...(apps.length
        ? [
            {
              text: 'Open With',
              items: apps.map((app) => ({
                text: app.name + (app.isDefault ? ' (default)' : ''),
                action: () => run('open', { app: app.path }),
              })),
            },
          ]
        : []),
      { item: 'Separator' },
      {
        text: navigator.platform.includes('Mac')
          ? 'Show in Finder'
          : 'Show in File Manager',
        action: () => run('reveal'),
      },
      ...(items.some((item) => item.originalPath)
        ? [
            {
              text: navigator.platform.includes('Mac')
                ? 'Show Original in Finder'
                : 'Show Original in File Manager',
              action: () => run('revealOriginal'),
            },
          ]
        : []),
      { item: 'Separator' },
      {
        text: 'Copy',
        enabled: capabilities.copyFiles,
        action: () => run('copyFile'),
      },
      {
        text: items.length > 1 ? 'Copy Paths' : 'Copy Path',
        action: () => run('copyPath'),
      },
      ...(items.some((item) => item.originalPath)
        ? [
            {
              text: 'Copy Original Paths',
              action: () => run('copyOriginalPath'),
            },
          ]
        : []),
      { item: 'Separator' },
      ...(convert
        ? [
            {
              text: items.length > 1 ? 'Convert Images…' : 'Convert Image…',
              action: convert,
            },
            { item: 'Separator' as const },
          ]
        : []),
      { text: 'Rename…', enabled: items.length === 1, action: rename },
      { text: 'Remove from Shelf', action: () => run('remove') },
    ],
    point,
  );
}
