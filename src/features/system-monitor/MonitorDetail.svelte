<script lang="ts">
  import { type Snapshot, type Sample, type View } from './model';
  import OverviewDetail from './OverviewDetail.svelte';
  import CpuDetail from './CpuDetail.svelte';
  import MemoryDetail from './MemoryDetail.svelte';
  import StorageDetail from './StorageDetail.svelte';
  import PowerDetail from './PowerDetail.svelte';
  import NetworkDetail from './NetworkDetail.svelte';
  let {
    data,
    history,
    view,
    onview,
  }: {
    data: Snapshot;
    history: Sample[];
    view: View;
    onview: (view: View) => void;
  } = $props();
  let network = $derived(
    data.interfaces.find((i) => i.primary) ?? data.interfaces[0],
  );
  let headings = $derived({
    overview: ['Your Mac, at a glance', `${data.model} · ${data.chip}`],
    cpu: ['CPU', `${data.chip} · ${data.logicalCores ?? '—'} logical cores`],
    memory: ['Memory', 'Understand pressure, not just fullness'],
    storage: [
      'Storage',
      `${data.storage.name ?? 'Startup disk'} · ${data.storage.format?.toUpperCase() ?? 'Unavailable'}`,
    ],
    power: ['Power', data.battery.source ?? 'No internal battery detected'],
    network: [
      'Network',
      network ? `Active interface · ${network.name}` : 'No connected interface',
    ],
  });
</script>

<div class="monitor-heading">
  <div>
    <h1>{headings[view][0]}</h1>
    <p>{headings[view][1]}</p>
  </div>
</div>
{#if view === 'overview'}<OverviewDetail {data} {history} {onview} />
{:else if view === 'cpu'}<CpuDetail {data} {history} />
{:else if view === 'memory'}<MemoryDetail {data} {history} />
{:else if view === 'storage'}<StorageDetail {data} />
{:else if view === 'power'}<PowerDetail {data} />
{:else if view === 'network'}<NetworkDetail {data} {history} />
{/if}
