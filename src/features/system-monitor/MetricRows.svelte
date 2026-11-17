<script lang="ts">
  let { rows }: { rows: { label: string; value: string; tone?: string }[] } =
    $props();
</script>

<dl class="monitor-rows">
  {#each rows as row}<div>
      <dt>{row.label}</dt>
      <dd data-tone={row.tone}>{row.value}</dd>
    </div>{/each}
</dl>
