/** Register before mounting UI so tool, dialog, and popup handlers cannot consume it. */
export function initializeRootSearchShortcut(
  openRoot: () => void,
  target: EventTarget = window,
) {
  const keydown = (event: Event) => {
    const key = event as KeyboardEvent;
    if (
      key.key !== 'Escape' ||
      !(key.metaKey || key.ctrlKey) ||
      key.isComposing
    )
      return;
    key.preventDefault();
    key.stopImmediatePropagation();
    if (!key.repeat) openRoot();
  };
  target.addEventListener('keydown', keydown, true);
  return () => target.removeEventListener('keydown', keydown, true);
}
