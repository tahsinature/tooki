<script lang="ts">
  import registry from './commands.json';
  import { assignment } from './assignments.svelte';
  import AssignmentRow from './AssignmentRow.svelte';
  import AssignmentGroup from '../../components/settings/AssignmentGroup.svelte';
  let { tool }: { tool: string } = $props();
</script>

<AssignmentGroup title="Commands">
  {#each registry.filter((command) => command.tool === tool) as command (command.id)}
    <AssignmentRow item={assignment(command.id, command.title, tool)} />
  {/each}
</AssignmentGroup>
