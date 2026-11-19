function visible(element: HTMLElement): boolean {
  return element.getClientRects().length > 0 && !element.closest('[inert]');
}

function searchInput(): HTMLInputElement | undefined {
  // A popup owns its search. Never move focus behind a modal dialog.
  const scope =
    Array.from(
      document.querySelectorAll<HTMLElement>('dialog[open], [role="dialog"]'),
    )
      .filter(visible)
      .at(-1) ?? document;
  const inputs = Array.from(
    scope.querySelectorAll<HTMLInputElement>('input[data-search-input]'),
  ).filter((input) => !input.disabled && visible(input));
  return (
    inputs.find((input) => !input.closest('.settings-sidebar')) ?? inputs[0]
  );
}

export function initializeSearchShortcut() {
  const mac = /Mac/.test(navigator.platform);
  const keydown = (event: KeyboardEvent) => {
    if (
      event.isComposing ||
      event.defaultPrevented ||
      !(mac ? event.metaKey : event.ctrlKey) ||
      event.shiftKey ||
      event.altKey ||
      event.key.toLowerCase() !== 'f' ||
      document.querySelector('.shortcut-record-button[aria-pressed="true"]')
    )
      return;
    const input = searchInput();
    if (!input) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    input.focus();
    input.select();
  };
  window.addEventListener('keydown', keydown, true);
  return () => window.removeEventListener('keydown', keydown, true);
}
