<script lang="ts">
  import MetricRows from './MetricRows.svelte';
  import TrendChart from './TrendChart.svelte';
  import { percent, type Snapshot, type Sample } from './model';
  let { data, history }: { data: Snapshot; history: Sample[] } = $props();
</script>

<section class="monitor-card">
  <div class="monitor-value" data-tone="green">
    {percent(data.cpu.total)}<span>Total CPU usage</span>
  </div>
  <TrendChart
    label="CPU usage over the last minute"
    values={history.map((s) => ({ time: s.time, value: s.cpu }))}
  />
</section>
<section>
  <h2>Per logical core</h2>
  <div class="monitor-cores">
    {#each data.cpu.cores as load, i}<div>
        <span>Core {i + 1}</span><meter
          min="0"
          max="100"
          value={load ?? 0}
          aria-label={`Core ${i + 1} usage`}
        ></meter><strong>{load == null ? '—' : percent(load)}</strong>
      </div>{/each}
  </div>
</section>
<section class="monitor-card">
  <h2>Top processes · 100% = one core</h2>
  <MetricRows
    rows={data.topCpu.map((p) => ({
      label: `${p.name} · ${p.pid}`,
      value: percent(p.cpu),
    }))}
  />
  <p class="monitor-note">
    Only processes macOS allows Tooki to inspect are listed.
  </p>
</section>
<MetricRows
  rows={[
    {
      label: 'Load average · 1 / 5 / 15 min',
      value:
        data.loadAverage?.map((n) => n.toFixed(2)).join(' / ') ?? 'Unavailable',
    },
    {
      label: 'Physical / logical cores',
      value: `${data.physicalCores ?? '—'} / ${data.logicalCores ?? '—'}`,
    },
    ...(data.efficiencyCores != null
      ? [
          {
            label: 'Performance / efficiency cores',
            value: `${data.performanceCores} / ${data.efficiencyCores}`,
          },
        ]
      : []),
  ]}
/>
