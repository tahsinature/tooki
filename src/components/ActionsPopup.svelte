<script lang="ts">
  import ActionsMenu from './ActionsMenu.svelte';
  import PopupSurface from './PopupSurface.svelte';
  import { Copy, Pin } from '@lucide/svelte';
  let {
    clipboard,
    primaryLabel = 'Open command',
    pinned,
    oncopy,
    onpin,
    onclose,
  }: {
    clipboard: boolean;
    primaryLabel?: string;
    pinned: boolean;
    oncopy: () => void;
    onpin: () => void;
    onclose: () => void;
  } = $props();
</script>

<PopupSurface title="Actions" {onclose}>
  <ActionsMenu
    actions={clipboard
      ? [
          {
            id: 'copy',
            label: 'Copy text',
            icon: Copy,
            run: oncopy,
            shortcut: '↵',
          },
          {
            id: 'pin',
            label: pinned ? 'Unpin clip' : 'Pin clip',
            icon: Pin,
            run: onpin,
          },
        ]
      : [
          {
            id: 'open',
            label: primaryLabel,
            icon: Copy,
            run: oncopy,
            shortcut: '↵',
          },
        ]}
  />
</PopupSurface>
