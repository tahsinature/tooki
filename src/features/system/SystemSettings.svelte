<script lang="ts">
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
</script>

<p class="settings-note">
  Put your computer to sleep, empty Trash, or safely eject a disk. Empty Trash
  always asks for confirmation. Unsupported actions keep their saved assignments
  but cannot run.
</p>
<ToolCommands tool="system" />
