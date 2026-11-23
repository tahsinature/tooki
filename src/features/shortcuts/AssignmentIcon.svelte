<script lang="ts">
  import {
    Keyboard,
    NotebookPen,
    ClipboardList,
    Smile,
    TextCursorInput,
    Coffee,
    Settings,
    Activity,
    AppWindow,
  } from '@lucide/svelte';
  let { group }: { group: string } = $props();
  const icons = {
    general: Keyboard,
    notes: NotebookPen,
    clipboard: ClipboardList,
    emoji: Smile,
    snippets: TextCursorInput,
    keepawake: Coffee,
    system: Settings,
    systemactions: Settings,
    systemmonitor: Activity,
    applications: AppWindow,
    builtin: Settings,
  };
  const Icon = $derived(
    icons[group.toLowerCase().replace(/[ -]/g, '') as keyof typeof icons] ??
      Keyboard,
  );
</script>

<span class="assignment-icon" aria-hidden="true"
  ><Icon size={15} strokeWidth={1.7} /></span
>

<style>
  .assignment-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    flex-shrink: 0;
    color: var(--muted);
  }
</style>
