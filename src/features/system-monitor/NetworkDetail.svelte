<script lang="ts">
  import MetricCard from './MetricCard.svelte';
  import MetricRows from './MetricRows.svelte';
  import TrendChart from './TrendChart.svelte';
  import { bytes, speed, type Snapshot, type Sample } from './model';
  let { data, history }: { data: Snapshot; history: Sample[] } = $props();
  let network = $derived(
    data.interfaces.find((i) => i.primary) ?? data.interfaces[0],
  );
</script>

{#if network}
  <div class="monitor-metrics two">
    <MetricCard
      label="Download"
      value={speed(network.download)}
      note={network.name}
      tone="blue"
    /><MetricCard
      label="Upload"
      value={speed(network.upload)}
      note={network.name}
    />
  </div>
  <section class="monitor-card">
    <h2>Download · Last 60 seconds</h2>
    <TrendChart
      label="Download rate over the last minute"
      tone="blue"
      max={Math.max(
        1,
        ...history
          .filter((s) => s.interface === network?.name)
          .map((s) => s.download ?? 0),
      )}
      values={history.map((s) => ({
        time: s.time,
        value: s.interface === network?.name ? s.download : null,
      }))}
    />
  </section>
  <MetricRows
    rows={[
      { label: 'Active interface', value: network.name },
      { label: 'Local address', value: network.address },
      { label: 'Received · interface total', value: bytes(network.received) },
      { label: 'Sent · interface total', value: bytes(network.sent) },
    ]}
  />
  {#if data.interfaces.length > 1}<section class="monitor-card">
      <h2>Other connected interfaces</h2>
      <MetricRows
        rows={data.interfaces
          .filter((i) => i.name !== network?.name)
          .map((i) => ({
            label: i.name,
            value: `${speed(i.download)} ↓ · ${speed(i.upload)} ↑`,
          }))}
      />
    </section>{/if}
  <p class="monitor-note">
    Rates belong to the active interface. VPN and physical interfaces can carry
    the same traffic; their totals are not added together.
  </p>
{:else}<section class="monitor-card">
    <h2>No connected interface</h2>
    <p class="monitor-note">Connect to a network to see transfer rates.</p>
  </section>{/if}
