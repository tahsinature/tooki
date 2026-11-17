<script lang="ts">
  let {
    label,
    value,
    note,
    tone = 'green',
  }: { label: string; value: string; note: string; tone?: string } = $props();
</script>

<div class="monitor-card monitor-metric" data-tone={tone}>
  <span class="monitor-label">{label}</span><strong>{value}</strong><span
    class="monitor-note">{note}</span
  >
</div>
