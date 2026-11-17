<script lang="ts">
  import { Check } from '@lucide/svelte';
  import type { Theme } from '../../lib/themes/theme';
  let { theme, selected, onclick }: { theme: Theme; selected: boolean; onclick: () => void } = $props();
</script>
<button class="theme-card" class:chosen={selected} aria-pressed={selected} {onclick}>
  <span class="theme-swatch" aria-hidden="true" style:background={theme.tokens.surface} style:border-color={theme.tokens.line}>
    <span style:background={theme.tokens.muted}></span>
    <span style:background={theme.tokens.selected}></span>
    <span style:background={theme.tokens.panel}></span>
  </span>
  <span class="theme-card-label"><strong>{theme.name}</strong><small>{theme.author}</small></span>
  <span class="theme-card-check">{#if selected}<Check size={14} />{/if}</span>
</button>
