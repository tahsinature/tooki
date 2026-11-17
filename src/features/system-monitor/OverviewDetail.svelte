<script lang="ts">
  import MetricCard from './MetricCard.svelte';
  import MetricRows from './MetricRows.svelte';
  import TrendChart from './TrendChart.svelte';
  import { CircleAlert, ArrowUpRight } from '@lucide/svelte';
  import {
    bytes,
    memoryBytes,
    percent,
    speed,
    duration,
    pressure,
    pressureTone,
    type Snapshot,
    type Sample,
    type View,
  } from './model';
  let {
    data,
    history,
    onview,
  }: { data: Snapshot; history: Sample[]; onview: (view: View) => void } =
    $props();
  let network = $derived(
    data.interfaces.find((i) => i.primary) ?? data.interfaces[0],
  );
  let available = $derived(data.storage.available);
  let total = $derived(data.storage.total);
  let usedPercent = $derived(
    total && available != null ? ((total - available) / total) * 100 : null,
  );
  let pressureText = $derived(pressure(data.memory?.pressure));
  let memoryTone = $derived(pressureTone(data.memory?.pressure));
</script>

<div class="monitor-metrics">
  <MetricCard
    label="CPU"
    value={percent(data.cpu.total)}
    note={`${data.logicalCores ?? '—'} logical cores`}
  />
  <MetricCard
    label="Memory used"
    value={memoryBytes(data.memory?.used)}
    note={`of ${memoryBytes(data.memoryTotal)}`}
    tone={memoryTone}
  />
  <MetricCard
    label="Storage free"
    value={bytes(available)}
    note={total && available != null
      ? `${Math.round((available / total) * 100)}% available`
      : 'Unavailable'}
    tone={usedPercent != null && usedPercent > 80 ? 'amber' : 'green'}
  />
</div>
{#if data.memory?.pressure === 2 || data.memory?.pressure === 4}
  <button
    class="monitor-insight monitor-card"
    onclick={() => onview('memory')}
    data-tone={memoryTone}
    ><CircleAlert size={18} /><span
      ><strong>Memory pressure is {pressureText.toLowerCase()}</strong><small
        >Review the largest apps in Memory.</small
      ></span
    ><ArrowUpRight size={15} /></button
  >
{/if}
<section class="monitor-card">
  <h2>CPU · Last 60 seconds</h2>
  <TrendChart
    label="CPU usage over the last minute"
    values={history.map((s) => ({ time: s.time, value: s.cpu }))}
  />
</section>
<MetricRows
  rows={[
    {
      label: 'Battery',
      value:
        data.battery.percent == null
          ? 'No internal battery'
          : `${percent(data.battery.percent)} · ${data.battery.charging ? 'charging' : data.battery.source === 'AC Power' ? 'plugged in' : 'unplugged'}`,
    },
    { label: 'Uptime', value: duration(data.uptime) },
    {
      label: 'Download / upload',
      value: network
        ? `${speed(network.download)} / ${speed(network.upload)}`
        : 'Disconnected',
    },
    { label: 'Hostname', value: data.hostname },
    { label: 'macOS', value: data.os },
    { label: 'Readable processes', value: String(data.processCount) },
  ]}
/>
