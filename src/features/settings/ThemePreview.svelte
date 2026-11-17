<script lang="ts">
  import SearchHeader from '../../components/SearchHeader.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import { activeTheme } from '../../lib/themes/store.svelte';
  import { commands } from '../../lib/data';
  import { themeVariables, type Theme } from '../../lib/themes/theme';
  let { theme }: { theme: Theme } = $props();
  let variables = $derived(
    Object.entries({
      // Clear inherited component overrides before applying the draft.
      ...Object.fromEntries(
        Object.keys(themeVariables(activeTheme())).map((key) => [
          key,
          'initial',
        ]),
      ),
      ...themeVariables(theme),
    })
      .map(([key, value]) => `${key}:${value}`)
      .join(';'),
  );
</script>

<section aria-label="Theme preview">
  <h3>Live preview</h3>
  <div class="preview-stage">
    <div
      class="preview-window"
      style={variables + `;color-scheme:${theme.appearance}`}
      inert
    >
      <SearchHeader
        query=""
        filter="all"
        clipboard={false}
        placeholder="Search apps and commands…"
      />
      <div class="preview-content">
        <ResultRow
          item={commands[0]}
          selected={true}
          index={0}
          onclick={() => {}}
          onopen={() => {}}
        />
      </div>
    </div>
  </div>
</section>

<style>
  section {
    position: sticky;
    /* Leave the shared sticky dialog heading visible above the preview. */
    top: max(0px, calc(var(--dialog-heading-height, 54px) - 18px));
    z-index: 1;
    background: var(--popup-background, var(--panel));
    border-bottom: 1px solid var(--line);
    padding: 12px 0;
  }
  h3 {
    font-size: 11px;
    font-weight: 500;
    color: var(--muted);
    margin: 0 0 8px;
  }
  .preview-stage {
    height: 156px;
    overflow: auto;
    padding: 6px;
    background: var(--sidebar);
    border-radius: var(--radius-control);
  }
  .preview-window {
    background: var(--surface);
    color: var(--ink);
    border: 1px solid var(--line);
    border-radius: var(--shell-radius);
    overflow: hidden;
    font-size: var(--font-size);
  }
  .preview-content {
    padding: var(--content-spacing);
  }
</style>
