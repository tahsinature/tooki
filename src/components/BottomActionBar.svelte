<script lang="ts">
  import type { Component } from 'svelte';
  import appIcon from '../../src-tauri/icons/icon.png';
  import { placementState } from '../features/launcher/placement.svelte';
  import { ClipboardList, Settings, Grip } from '@lucide/svelte';
  import Keycap from './Keycap.svelte';
  import { shortcutLabels } from '../lib/shortcut';
  let {
    clipboard,
    toolIcon: ToolIcon = ClipboardList,
    count,
    selectedIndex,
    status,
    onprimary,
    onactions,
    disabled,
    onsettings,
    onappmenu,
    appMenuOpen = false,
    compact = false,
    onexpand,
    ondrag,
    primaryLabel,
    secondaryAction,
  }: {
    secondaryAction?: {
      label: string;
      shortcut?: string;
      disabled?: boolean;
      run: () => void;
    };
    toolIcon?: Component<{ size?: number }>;
    primaryLabel?: string;
    ondrag?: (event: PointerEvent) => void;
    compact?: boolean;
    onexpand?: () => void;
    clipboard: boolean;
    count: number;
    selectedIndex: number;
    status: string;
    onprimary: () => void;
    onactions: () => void;
    disabled: boolean;
    onsettings?: () => void;
    onappmenu?: (event: MouseEvent) => void;
    appMenuOpen?: boolean;
  } = $props();
</script>

<footer class="bottom-action-bar">
  {#if clipboard}
    <div class="footer-identity">
      <span class="brand-icon"><ToolIcon size={17} /></span><strong
        >{count && selectedIndex >= 0 ? Math.min(selectedIndex + 1, count) : 0} of
        {count}</strong
      >
    </div>
    {#if onsettings}<button
        class="icon-button settings-trigger"
        onclick={onsettings}
        aria-label="Open settings"
        title="Settings"><Settings size={16} /></button
      >{/if}
  {:else}
    <button
      class="footer-identity app-menu-trigger"
      onclick={onappmenu}
      aria-label="Tooki menu"
      aria-haspopup="dialog"
      aria-expanded={appMenuOpen}
    >
      <span class="brand-icon"
        ><img src={appIcon} alt="" width="20" height="20" /></span
      ><strong>Tooki</strong>
    </button>
  {/if}
  <span class="status" role="status">{status || placementState.error}</span>
  <div class="footer-actions">
    {#if ondrag}<button
        onpointerdown={ondrag}
        {disabled}
        title="Drag this clip to another app"><Grip size={15} /> Drag</button
      >{/if}
    {#if compact}<button onclick={onexpand}
        >Show More <Keycap text="↓" /></button
      >{:else}
      {#if secondaryAction}<button
          onclick={secondaryAction.run}
          disabled={secondaryAction.disabled ?? false}
          >{secondaryAction.label}
          {#each shortcutLabels(secondaryAction.shortcut ?? '') as key}<Keycap
              text={key}
            />{/each}</button
        ><span class="footer-separator" aria-hidden="true"></span>{/if}
      <button onclick={onprimary} {disabled}
        >{primaryLabel ?? (clipboard ? 'Copy' : 'Open')}
        <Keycap text="↵" /></button
      ><span class="footer-separator"></span><button
        onclick={onactions}
        {disabled}>Actions <Keycap text="⌘" /><Keycap text="K" /></button
      >
    {/if}
  </div>
</footer>
