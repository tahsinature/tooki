import { Menu, type MenuOptions } from '@tauri-apps/api/menu';
import { LogicalPosition, getCurrentWindow } from '@tauri-apps/api/window';

/** Shelf uses contextual OS menus, as the Swift panel does. No window resize. */
export async function showShelfMenu(
  items: MenuOptions['items'],
  point?: { x: number; y: number },
) {
  const menu = await Menu.new({ items });
  try {
    await menu.popup(
      point ? new LogicalPosition(point.x, point.y) : undefined,
      getCurrentWindow(),
    );
  } finally {
    await menu.close();
  }
}
