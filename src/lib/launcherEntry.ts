export type LauncherEntry = { mode: 'resume' | 'fresh'; target: string | null };
export type ToolView =
  'clipboard' | 'snippets' | 'emoji' | 'systemMonitor' | 'system';

export function toolEntry(target: string): { view: ToolView; filter: string } {
  if (target.startsWith('command:clipboard.')) {
    return {
      view: 'clipboard',
      filter: target.endsWith('.pinned')
        ? 'pinned'
        : target.endsWith('.links')
          ? 'link'
          : 'all',
    };
  }
  const view = {
    'command:snippets.open': 'snippets',
    'command:emoji.open': 'emoji',
    'command:systemMonitor.open': 'systemMonitor',
  }[target] as ToolView | undefined;
  if (view) return { view, filter: 'all' };
  if (
    target.startsWith('command:system.') ||
    target === 'command:keepAwake.open'
  )
    return { view: 'system', filter: 'all' };
  throw new Error(`Unknown launcher destination: ${target}`);
}

// Resume deliberately leaves the mounted tool untouched. Fresh entry unmounts
// it before opening, including when the same tool was already on screen.
export async function enterLauncher(
  entry: LauncherEntry,
  reset: () => void,
  flush: () => Promise<void>,
  open: (target: string) => void,
  current: () => boolean,
): Promise<boolean> {
  if (!current()) return false;
  if (entry.mode === 'resume') return true;
  reset();
  await flush();
  if (!current()) return false;
  if (entry.target) open(entry.target);
  return true;
}
