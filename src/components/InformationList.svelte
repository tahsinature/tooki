<script lang="ts">
  let {
    title = 'Information',
    entries,
  }: {
    title?: string;
    entries: { label: string; value: string | number }[];
  } = $props();
</script>

<div class="information" role="group" aria-label={title}>
  <dl>
    {#each entries as entry}
      <div>
        <dt>{entry.label}</dt>
        <dd>{entry.value}</dd>
      </div>
    {/each}
  </dl>
</div>
