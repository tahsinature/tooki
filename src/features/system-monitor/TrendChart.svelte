<script lang="ts">
  import { trendPoints } from './model';
  let {
    values,
    label,
    max = 100,
    tone = 'green',
  }: {
    values: { time: number; value: number | null }[];
    label: string;
    max?: number;
    tone?: string;
  } = $props();
  let now = $derived(values.at(-1)?.time ?? Date.now());
  let paths = $derived(trendPoints(values, max, now));
</script>

<div class="monitor-chart" data-tone={tone}>
  <svg
    viewBox="0 0 440 72"
    preserveAspectRatio="none"
    role="img"
    aria-label={label}
  >
    <path d="M0 66 H440 M0 36 H440 M0 6 H440" class="monitor-chart-grid" />
    {#each paths as path}<path d={path} class="monitor-chart-line" />{/each}
  </svg>
  <div class="monitor-chart-axis"><span>60s ago</span><span>Now</span></div>
</div>
