<script lang="ts">
  import registry from './commands.json';
  import { assignment } from './assignments.svelte';
  import AssignmentRow from './AssignmentRow.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  let { tool }: { tool: string } = $props();
</script>

<SettingsSection
  title="Commands"
  description="Assign an alias or a global shortcut. Changes also appear in Shortcuts."
>
  {#each registry.filter((command) => command.tool === tool) as command (command.id)}
    <AssignmentRow item={assignment(command.id, command.title, tool)} />
  {/each}
</SettingsSection>
