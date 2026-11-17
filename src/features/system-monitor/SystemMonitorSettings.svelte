<script lang="ts">
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
</script>

<p class="settings-note">
  A live view of CPU, memory, storage, power, and network activity. Available on
  macOS.
</p>
<SettingsSection title="Live readings">
  <SettingsRow
    title="Refresh interval"
    description="Readings update while System Monitor is visible. Sampling pauses when the launcher is hidden."
    >2 seconds</SettingsRow
  >
  <SettingsRow
    title="Recent history"
    description="Charts keep the last minute in memory. Readings are not saved or uploaded."
    >60 seconds</SettingsRow
  >
</SettingsSection>
<ToolCommands tool="systemMonitor" />
<p class="settings-note">
  Some hardware readings may be unavailable. Memory pressure is reported by
  macOS; a high used-memory percentage alone does not indicate a problem.
</p>
