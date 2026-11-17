<script lang="ts">
  import type { Snippet } from 'svelte';
  import { Info, X } from '@lucide/svelte';
  let { title, children }: { title: string; children: Snippet } = $props();
  const id = $props.id();
  let trigger: HTMLButtonElement;
  let panel: HTMLDivElement;
  let open = $state(false);
  function position() {
    const anchor = trigger.getBoundingClientRect();
    const width = Math.min(340, window.innerWidth - 24);
    panel.style.width = `${width}px`;
    panel.style.left = `${Math.max(12, Math.min(anchor.left, window.innerWidth - width - 12))}px`;
    const height = panel.getBoundingClientRect().height;
    panel.style.top = `${Math.max(12, Math.min(anchor.bottom + 8, window.innerHeight - height - 12))}px`;
  }
  function toggle() {
    if (open) panel.hidePopover();
    else {
      panel.showPopover();
      position();
      panel.focus({ preventScroll: true });
    }
  }
  function close() {
    panel.hidePopover();
    trigger.focus({ preventScroll: true });
  }
</script>

<svelte:window
  onresize={() => {
    if (open) position();
  }}
/>
<button
  bind:this={trigger}
  class="info-trigger icon-button"
  aria-label={title}
  aria-haspopup="dialog"
  aria-expanded={open}
  aria-controls={id}
  onclick={toggle}><Info size={14} /></button
>
<div
  bind:this={panel}
  {id}
  popover="auto"
  role="dialog"
  aria-label={title}
  tabindex="-1"
  class="popup info-popover"
  ontoggle={(event) => {
    open = event.newState === 'open';
  }}
  onkeydown={(event) => {
    if (event.key === 'Escape') {
      event.preventDefault();
      event.stopPropagation();
      close();
    }
  }}
>
  <div class="popup-heading">
    {title}<button
      class="icon-button"
      aria-label="Close information"
      onclick={close}><X size={14} /></button
    >
  </div>
  <div class="info-popover-content">{@render children()}</div>
</div>

<style>
  .info-trigger {
    display: inline-flex;
    vertical-align: middle;
    padding: 3px;
    color: var(--muted);
  }
  .info-trigger:hover {
    color: var(--ink);
  }
  .info-popover {
    position: fixed;
    inset: auto;
    margin: 0;
    max-height: calc(100dvh - 24px);
    overflow: auto;
    padding: 12px;
  }
  .info-popover:not(:popover-open) {
    display: none;
  }
  .info-popover-content {
    font-size: 12px;
    line-height: 1.55;
    color: var(--muted);
  }
  .info-popover-content :global(p) {
    margin: 10px 0 0;
  }
</style>
