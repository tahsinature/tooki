<script lang="ts">
  let { checked, label, onchange, disabled = false }: { checked: boolean; label: string; onchange: (checked: boolean) => void; disabled?: boolean } = $props();
</script>
<button type="button" class="toggle" role="switch" aria-checked={checked} aria-label={label} {disabled} onclick={() => onchange(!checked)}><span></span></button>
