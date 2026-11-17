<script lang="ts">
  import { Search } from '@lucide/svelte';
  let { title = 'No results', description = 'Try another word or change the filter.' }: {
    title?: string; description?: string;
  } = $props();
</script>

<div class="empty" role="status">
  <Search size={30} strokeWidth={1.2} />
  <h2>{title}</h2>
  <p>{description}</p>
</div>
