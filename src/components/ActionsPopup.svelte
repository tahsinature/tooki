<script lang="ts">
  import ActionsMenu from './ActionsMenu.svelte';
  import PopupSurface from './PopupSurface.svelte';
  import { Copy, Pin, RefreshCw } from '@lucide/svelte';
  let {
    clipboard,
    primaryLabel = 'Open command',
    pinned,
    oncopy,
    onpin,
    onrefresh,
    refreshing = false,
    onclose,
  }: {
    clipboard: boolean;
    primaryLabel?: string;
    pinned: boolean;
    oncopy: () => void;
    onpin: () => void;
    onrefresh?: () => void;
    refreshing?: boolean;
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
          ...(onrefresh ? [{ id: 'refresh-applications', label: refreshing ? 'Refreshing Applications…' : 'Refresh Applications', icon: RefreshCw, run: onrefresh, disabled: refreshing }] : []),
        ]}
  />
</PopupSurface>
