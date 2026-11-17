export function shortcutFromEvent(event: Pick<KeyboardEvent, 'code' | 'metaKey' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'isComposing'>): string | null {
  if (event.isComposing || !(event.metaKey || event.ctrlKey || event.altKey)) return null;
  const code = event.code;
  if (!/^(Key[A-Z]|Digit[0-9]|F([1-9]|1[0-9]|2[0-4])|Space|Comma|Period|Slash|Backslash|Semicolon|Quote|BracketLeft|BracketRight|Backquote|Minus|Equal|ArrowUp|ArrowDown|ArrowLeft|ArrowRight|Home|End|PageUp|PageDown|Enter|Tab|Backspace|Delete)$/.test(code)) return null;
  return [event.metaKey && 'Super', event.ctrlKey && 'Control', event.altKey && 'Alt', event.shiftKey && 'Shift', code].filter(Boolean).join('+');
}

export function shortcutLabels(shortcut: string): string[] {
  const mac = typeof navigator !== 'undefined' && /Mac/.test(navigator.platform);
  const labels: Record<string, string> = { CommandOrControl: mac ? '⌘' : 'Ctrl', Super: mac ? '⌘' : 'Win', Control: 'Ctrl', Alt: mac ? '⌥' : 'Alt', Shift: '⇧', Comma: ',', Period: '.', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };
  return shortcut.split('+').filter(Boolean).map(key => labels[key] ?? key.replace(/^(Key|Digit)/, ''));
}
