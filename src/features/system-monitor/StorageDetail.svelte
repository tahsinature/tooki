<script lang="ts">
  import MetricRows from './MetricRows.svelte';
  import { bytes, percent, speed, type Snapshot } from './model';
  let { data }: { data: Snapshot } = $props();
  let available = $derived(data.storage.available);
  let total = $derived(data.storage.total);
  let usedPercent = $derived(
    total && available != null ? ((total - available) / total) * 100 : null,
  );
</script>

<section class="monitor-card">
  <div
    class="monitor-value"
    data-tone={usedPercent != null && usedPercent > 80 ? 'amber' : 'green'}
  >
    {bytes(available)}<span>available of {bytes(total)}</span>
  </div>
  {#if usedPercent != null}<meter
      class="monitor-storage-meter"
      min="0"
      max="100"
      value={usedPercent}
      aria-label="Storage used"
    ></meter>
    <div class="monitor-chart-axis">
      <span>Used {percent(usedPercent)}</span><span
        >Available {percent(100 - usedPercent)}</span
      >
    </div>{/if}
</section>
<MetricRows
  rows={[
    {
      label: 'Used',
      value:
        total != null && available != null
          ? bytes(total - available)
          : 'Unavailable',
    },
    {
      label: 'File system',
      value: data.storage.format?.toUpperCase() ?? 'Unavailable',
    },
    { label: 'SMART status', value: 'Unavailable' },
  ]}
/>
<section class="monitor-card">
  <h2>Disk activity · all physical drives</h2>
  <MetricRows
    rows={[
      {
        label: 'Read',
        value:
          data.storage.readRate == null
            ? 'Unavailable'
            : speed(data.storage.readRate),
        tone: 'blue',
      },
      {
        label: 'Write',
        value:
          data.storage.writeRate == null
            ? 'Unavailable'
            : speed(data.storage.writeRate),
        tone: 'green',
      },
    ]}
  />
</section>
<p class="monitor-note">
  Startup-volume space is shared by APFS volumes. Available space excludes
  reclaimable files, so Finder may show a different amount.
</p>
