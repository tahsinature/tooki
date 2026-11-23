import type { Item } from '../../lib/data';

// Bundled adapters only. Adding metadata does not grant code execution.
export const extensions = [
  {
    id: 'shelferry',
    name: 'Shelferry',
    description:
      'A place for everything you’re working with. Collect files on floating shelves and bring them into Tooki with a shortcut.',
    kind: 'External app',
    platform: 'macOS 14+',
    tool: 'shelf',
    keywords: 'shelf manager files drag drop floating',
  },
] as const;

export type Extension = (typeof extensions)[number];

export function extensionItem(extension: Extension): Item {
  return {
    id: extension.tool,
    title: extension.name,
    subtitle: extension.description,
    kind: 'command',
    metadata: '',
    group: 'Bundled extensions',
    content: extension.keywords,
    source: 'Tooki',
    time: '',
  };
}
