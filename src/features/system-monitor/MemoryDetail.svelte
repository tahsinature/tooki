<script lang="ts">
  import MetricRows from './MetricRows.svelte';
  import TrendChart from './TrendChart.svelte';
  import {
    memoryBytes,
    percent,
    pressure,
    pressureTone,
    type Snapshot,
    type Sample,
  } from './model';
  let { data, history }: { data: Snapshot; history: Sample[] } = $props();
  let memoryPercent = $derived(
    data.memory ? (data.memory.used / data.memoryTotal) * 100 : null,
  );
  let pressureText = $derived(pressure(data.memory?.pressure));
  let memoryTone = $derived(pressureTone(data.memory?.pressure));
</script>

<section class="monitor-card">
  <div class="monitor-value" data-tone={memoryTone}>
    {memoryBytes(data.memory?.used)}<span
      >used of {memoryBytes(data.memoryTotal)} · {memoryPercent == null
        ? 'Unavailable'
        : percent(memoryPercent)}</span
    >
  </div>
  <TrendChart
    label="Memory usage over the last minute"
    tone={memoryTone}
    values={history.map((s) => ({ time: s.time, value: s.memory }))}
  /><MetricRows
    rows={[{ label: 'Memory pressure', value: pressureText, tone: memoryTone }]}
  />
</section>
<MetricRows
  rows={[
    { label: 'Compressed', value: memoryBytes(data.memory?.compressed) },
    { label: 'Wired', value: memoryBytes(data.memory?.wired) },
    {
      label: 'Available / reclaimable',
      value: data.memory
        ? memoryBytes(Math.max(0, data.memoryTotal - data.memory.used))
        : 'Unavailable',
    },
    { label: 'Swap used', value: memoryBytes(data.swapUsed) },
  ]}
/>
<section class="monitor-card">
  <h2>Largest processes · memory footprint</h2>
  <MetricRows
    rows={data.topMemory.map((p) => ({
      label: `${p.name} · ${p.pid}`,
      value: memoryBytes(p.memory),
    }))}
  />
</section>
<p class="monitor-note">
  Pressure reflects how hard macOS is working to provide memory. Open Activity
  Monitor to inspect an app.
</p>
