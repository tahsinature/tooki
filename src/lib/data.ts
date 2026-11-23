export type Item = {
  id: string;
  title: string;
  subtitle: string;
  parentTitle?: string;
  metadata?: string;
  icon?: string;
  snippetTrigger?: string;
  kind:
    | 'application'
    | 'command'
    | 'text'
    | 'link'
    | 'code'
    | 'image'
    | 'file'
    | 'color';
  group: string;
  content: string;
  source: string;
  time: string;
  pinned?: boolean;
};
export const commands: Item[] = [
  {
    id: 'systemMonitor',
    title: 'System Monitor',
    subtitle: 'Your Mac, at a glance',
    kind: 'command',
    group: 'Commands',
    content:
      'cpu memory ram storage disk battery power network performance activity monitor',
    source: 'Tooki',
    time: '',
  },
  {
    id: 'emoji',
    title: 'Emoji Picker',
    subtitle: 'Find and copy emoji',
    kind: 'command',
    group: 'Commands',
    content: 'smile emoticon unicode symbols',
    source: 'Tooki',
    time: '',
  },
  {
    id: 'snippets',
    title: 'Snippets',
    subtitle: 'Expand text, dates, and templates',
    kind: 'command',
    group: 'Commands',
    content: 'snippet text expansion email templates date',
    source: 'Tooki',
    time: '',
  },
  {
    id: 'keepAwake',
    title: 'Keep Awake',
    subtitle: 'Prevent idle sleep with a timed session',
    kind: 'command',
    group: 'Commands',
    content: 'keep awake wake lock caffeine coffee display sleep',
    source: 'Tooki',
    time: '',
  },
  {
    id: 'system',
    title: 'System Actions',
    subtitle: 'Sleep, empty Trash, and eject disks',
    kind: 'command',
    group: 'Commands',
    content: 'sleep empty trash eject disk',
    source: 'Tooki',
    time: '',
  },
  {
    id: 'notes',
    title: 'Notes',
    subtitle: 'Write, find and keep your thoughts',
    kind: 'command',
    group: 'Commands',
    content: 'quick notes writing',
    source: 'Tooki',
    time: '',
  },

  {
    id: 'clipboard',
    title: 'Clipboard History',
    subtitle: 'Find something you copied',
    kind: 'command',
    group: 'Commands',
    content: '',
    source: 'Tooki',
    time: '',
  },

  {
    id: 'settings',
    title: 'Tooki Settings',
    subtitle: 'Appearance, themes, and preferences',
    kind: 'command',
    group: 'Commands',
    content: '',
    source: 'Tooki',
    time: '',
  },
];
export const samples: Item[] = [
  {
    id: 'welcome',
    title: 'A little less searching. A little more doing.',
    subtitle: 'A note for the next version of Tooki',
    kind: 'text',
    group: 'Today',
    source: 'Notes',
    time: '2 min ago',
    pinned: true,
    content:
      'A little less searching.\nA little more doing.\n\nA quiet place for the things you use every day. Open an app, find a thought, or pick up exactly where you left off.\n\nSmall details. Shared components. Familiar shortcuts.',
  },
  {
    id: 'url',
    title: 'Svelte • Cybernetically enhanced web apps',
    subtitle: 'https://svelte.dev',
    kind: 'link',
    group: 'Today',
    source: 'Safari',
    time: '8 min ago',
    content: 'https://svelte.dev',
  },
  {
    id: 'code',
    title: 'A small, thoughtful component',
    subtitle: 'TypeScript · 6 lines',
    kind: 'code',
    group: 'Today',
    source: 'Visual Studio Code',
    time: '14 min ago',
    content:
      'type Clip = {\n  id: string;\n  text: string;\n  pinned: boolean;\n};\n\nconst useful = clips.filter(clip => clip.pinned);',
  },
  {
    id: 'meeting',
    title: 'Notes from the design review',
    subtitle: 'Keep it simple. Make it feel familiar.',
    kind: 'text',
    group: 'Today',
    source: 'Notes',
    time: '26 min ago',
    content:
      'Notes from the design review\n\n• Use the same components everywhere.\n• Make keyboard navigation feel effortless.\n• Keep the preview readable.\n• Spend time on the little details.',
  },
  {
    id: 'color',
    title: '#8B9DCE',
    subtitle: 'A softer selection color',
    kind: 'text',
    group: 'Yesterday',
    source: 'Figma',
    time: 'Yesterday',
    content: '#8B9DCE',
  },
  {
    id: 'tauri',
    title: 'Tauri 2.0',
    subtitle: 'https://v2.tauri.app',
    kind: 'link',
    group: 'Yesterday',
    source: 'Safari',
    time: 'Yesterday',
    content: 'https://v2.tauri.app',
  },
  ...Array.from({ length: 24 }, (_, i): Item => ({
    id: `note-${i}`,
    title:
      [
        'Weekend reading list',
        'An idea worth keeping',
        'Project checklist',
        'A quick reminder',
      ][i % 4] + ` ${i + 1}`,
    subtitle: 'Sample text • Nothing from your real clipboard',
    kind: 'text',
    group: i < 6 ? 'Yesterday' : 'This Week',
    source: 'Notes',
    time: i < 6 ? 'Yesterday' : '3 days ago',
    content: `Sample note ${i + 1}\n\nThis is demonstration content for exploring the new Clipboard Manager.\n\nSearch, pin, copy, and navigate with your keyboard. Your real clipboard history is never read.`,
  })),
];
