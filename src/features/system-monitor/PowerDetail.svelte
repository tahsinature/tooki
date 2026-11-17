<script lang="ts">
  import MetricCard from './MetricCard.svelte';
  import MetricRows from './MetricRows.svelte';
  import { percent, duration, type Snapshot } from './model';
  let { data }: { data: Snapshot } = $props();
</script>

{#if data.battery.percent != null}
  <div class="monitor-metrics two">
    <MetricCard
      label="Battery remaining"
      value={percent(data.battery.percent)}
      note={data.battery.charging ? 'Charging' : 'Not charging'}
    /><MetricCard
      label="Estimated time left"
      value={duration(data.battery.remainingSeconds)}
      note="Changes with workload"
      tone="blue"
    />
  </div>
  <section class="monitor-card">
    <h2>Battery health</h2>
    <MetricRows
      rows={[
        {
          label: 'Maximum capacity',
          value:
            data.battery.health == null
              ? 'Unavailable'
              : percent(data.battery.health),
        },
        {
          label: 'Cycle count',
          value: data.battery.cycles?.toLocaleString() ?? 'Unavailable',
        },
        {
          label: 'Power source',
          value: data.battery.source ?? 'Unavailable',
        },
      ]}
    />
  </section>
  <p class="monitor-note">
    Capacity is the battery controller’s estimate relative to its design
    capacity. Time remaining may be unavailable while macOS recalculates it.
  </p>
{:else}<section class="monitor-card">
    <h2>No internal battery detected</h2>
    <p class="monitor-note">
      Battery readings are available on Macs with an internal battery.
    </p>
  </section>{/if}
