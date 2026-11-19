import { tick } from 'svelte';

export function disableBrowserContextMenu() {
  const preventDefault = (event: MouseEvent) => event.preventDefault();
  // Keep propagation intact so Tooki's own context menus still receive events.
  document.addEventListener('contextmenu', preventDefault, true);
  return () =>
    document.removeEventListener('contextmenu', preventDefault, true);
}

export async function openRowActions(
  event: MouseEvent,
  select: () => void,
  open?: () => void,
) {
  event.preventDefault();
  if (!open) return;
  select();
  // Actions must see the clicked row, including its newly derived preview state.
  await tick();
  open();
}
