<script lang="ts">
  import SearchField from '../../components/SearchField.svelte';
  import ResultRow from '../../components/ResultRow.svelte';
  import SectionHeader from '../../components/SectionHeader.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import ShelferrySettings from './ShelferrySettings.svelte';
  import { extensions, extensionItem } from './catalog';

  let query = $state('');
  let selected = $state<string>('shelferry');
  let visible = $derived(
    extensions.filter((extension) =>
      `${extension.name} ${extension.description} ${extension.keywords}`
        .toLowerCase()
        .includes(query.trim().toLowerCase()),
    ),
  );
  let current = $derived(
    visible.find((entry) => entry.id === selected) ?? visible[0],
  );
</script>

<div class="extensions-page">
  <div class="extensions-intro">
    <h1>Your extensions</h1>
    <p>Connect your apps to Tooki. Their commands, your shortcuts.</p>
  </div>
  <div class="extensions-layout">
    <aside class="extension-library" aria-label="Extensions">
      <SearchField
        label="Search extensions"
        placeholder="Search extensions…"
        bind:value={query}
      />
      <SectionHeader title="Bundled extensions" />
      {#each visible as extension, index (extension.id)}
        <ResultRow
          item={extensionItem(extension)}
          selected={current?.id === extension.id}
          {index}
          onclick={() => (selected = extension.id)}
          onopen={() => (selected = extension.id)}
        />
      {/each}
      <p class="settings-note">
        Included with Tooki.<br />Companion apps are installed separately.
      </p>
    </aside>
    <div class="extension-detail">
      {#if current?.id === 'shelferry'}
        <ShelferrySettings extension={current} />
      {:else}
        <EmptyState
          title="No matching extensions"
          description="Try searching for Shelferry or shelves."
        />
      {/if}
    </div>
  </div>
</div>

<style>
  .extensions-page {
    container-type: inline-size;
  }
  .extensions-intro {
    margin: 4px 0 24px;
  }
  .extensions-intro p {
    margin: 6px 0 0;
    color: var(--muted);
    line-height: 1.6;
  }
  .extensions-layout {
    display: grid;
    gap: 24px;
    align-items: start;
  }
  .extension-library {
    min-width: 0;
  }
  .extension-library :global(.section-heading) {
    margin-top: 16px;
  }
  .extension-library > p {
    margin: 12px 10px 0;
  }
  .extension-detail {
    min-width: 0;
  }
  @container (min-width: 720px) {
    .extensions-layout {
      grid-template-columns: 210px minmax(0, 1fr);
    }
    .extension-library {
      position: sticky;
      top: 16px;
    }
    .extension-detail {
      border-left: 1px solid var(--line);
      padding-left: 24px;
    }
  }
</style>
