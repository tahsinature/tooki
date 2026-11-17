<script lang="ts">
  import Dialog from '../../components/Dialog.svelte';
  import Button from '../../components/Button.svelte';
  import TextInput from '../../components/TextInput.svelte';
  import ThemePreview from './ThemePreview.svelte';
  import DimensionControl from '../../components/DimensionControl.svelte';
  import { colorTokens, presets, type Theme } from '../../lib/themes/theme';
  import { allThemes, saveEditedTheme } from '../../lib/themes/store.svelte';
  let { theme, onclose }: { theme: Theme; onclose: () => void } = $props();
  const copying = presets.some((item) => item.id === theme.id);
  function createDraft() {
    const copy: Theme = JSON.parse(JSON.stringify(theme));
    copy.tokens.cornerRadius ??= copy.tokens.shellRadius;
    if (copying) {
      let suffix = 1;
      do {
        copy.id = `${theme.id}-custom-${suffix++}`;
      } while (allThemes().some((item) => item.id === copy.id));
      copy.name = `${theme.name} custom`;
    }
    return copy;
  }
  let draft = $state(createDraft());
  let error = $state('');
  const controls = [
    { key: 'cornerRadius', label: 'Corner radius', min: 0, max: 24 },
    { key: 'fontSize', label: 'Text size', min: 12, max: 18 },
    { key: 'searchFontSize', label: 'Search text size', min: 14, max: 28 },
    { key: 'contentSpacing', label: 'Content spacing', min: 12, max: 32 },
    { key: 'rowHeight', label: 'Row height', min: 32, max: 64 },
    { key: 'headerHeight', label: 'Search header height', min: 44, max: 80 },
  ] as const;
  const labels: Record<string, string> = {
    surface: 'Window',
    panel: 'Panel',
    sidebar: 'Sidebar',
    ink: 'Text',
    muted: 'Secondary text',
    line: 'Borders',
    selected: 'Selected row',
    hover: 'Hover',
    accent: 'Accent',
    accentInk: 'Accent text',
    danger: 'Destructive actions',
    selectionMark: 'Selection indicator',
  };
  function save() {
    try {
      saveEditedTheme(draft);
      onclose();
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Could not save theme.';
    }
  }
</script>

<Dialog title="Edit theme" {onclose}>
  <p class="settings-note">
    {copying ? 'Save as a custom theme.' : 'Changes apply when you save.'}
  </p>
  <div class="theme-fields">
    <label
      >Name<TextInput
        class="text-field"
        bind:value={draft.name}
        maxlength={80}
      /></label
    >
    <label
      >Appearance<select bind:value={draft.appearance}
        ><option value="dark">Dark</option><option value="light">Light</option
        ></select
      ></label
    >
  </div>
  <div class="theme-dimensions">
    {#each controls as control}
      <DimensionControl
        id={'theme-' + control.key}
        label={control.label}
        min={control.min}
        max={control.max}
        value={draft.tokens[control.key] ?? control.min}
        onchange={(value) => (draft.tokens[control.key] = value)}
      />
    {/each}
  </div>
  <ThemePreview theme={draft} />
  <details>
    <summary>Colors <span>{colorTokens.length} colors</span></summary>
    <div class="theme-colors">
      {#each colorTokens as token}
        <label
          >{labels[token]}<input
            type="color"
            bind:value={draft.tokens[token]}
            aria-label={labels[token]}
          /></label
        >
      {/each}
    </div>
  </details>
  {#if Object.keys(draft.components).length}
    <p class="settings-note">
      Component overrides take priority over global styles.
    </p>
    <Button onclick={() => (draft.components = {})}
      >Use global styles for all components</Button
    >
  {/if}
  {#if error}<p class="error-message" role="alert">{error}</p>{/if}
  <div class="dialog-actions">
    <Button onclick={onclose}>Cancel</Button><Button
      disabled={!draft.name.trim()}
      onclick={save}>{copying ? 'Save custom theme' : 'Save changes'}</Button
    >
  </div>
</Dialog>

<style>
  .theme-fields {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 100px;
    gap: 12px;
    margin: 14px 0;
  }
  .theme-fields label {
    display: grid;
    gap: 6px;
    font-size: 12px;
  }
  select {
    width: 100%;
    color: var(--ink);
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: var(--radius-control);
    padding: 8px;
    font: inherit;
  }
  .theme-dimensions {
    display: grid;
    gap: 10px;
    padding: 12px 0;
    border-top: 1px solid var(--line);
  }
  summary {
    cursor: pointer;
    padding: 12px 0;
    font-size: 12px;
  }
  summary span {
    float: right;
    color: var(--muted);
  }
  .theme-colors {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px 18px;
    padding-bottom: 10px;
  }
  .theme-colors label {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    font-size: 12px;
  }
  input[type='color'] {
    width: 30px;
    height: 24px;
    padding: 2px;
    border: 1px solid var(--line);
    border-radius: var(--radius-control);
    background: var(--panel);
    cursor: pointer;
  }
</style>
