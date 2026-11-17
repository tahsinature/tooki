<script lang="ts">
  import FilterPopup from '../../components/FilterPopup.svelte';
  import { ChevronDown } from '@lucide/svelte';
  import { noteFonts, isNoteFont } from './fonts';
  const fontId = $props.id();
  let fontOpen = $state(false);
  let fontTrigger = $state<HTMLButtonElement>();
  function closeFont(restore = false) {
    fontOpen = false;
    if (restore) fontTrigger?.focus();
  }
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import { preferences, setPreference } from '../../lib/preferences.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
</script>

<SettingsSection title="Notes">
  <SettingsRow
    title="Font"
    description="Use this font for the content of all notes."
  >
    <button
      class="control-button"
      bind:this={fontTrigger}
      aria-haspopup="dialog"
      aria-expanded={fontOpen}
      aria-controls={fontId}
      onclick={() => (fontOpen = !fontOpen)}
    >
      {noteFonts.find((font) => font.value === preferences.notesFont)
        ?.label}<ChevronDown size={12} />
    </button>
    {#if fontOpen && fontTrigger}<FilterPopup
        id={fontId}
        anchor={fontTrigger}
        value={preferences.notesFont}
        label="Notes font"
        loadOptions={(query) =>
          noteFonts.filter((font) =>
            font.label.toLowerCase().includes(query.toLowerCase()),
          )}
        onchoose={(value) => {
          if (isNoteFont(value)) setPreference('notesFont', value);
          closeFont(true);
        }}
        onclose={closeFont}
      />{/if}
  </SettingsRow>
  <SettingsRow
    title="Formatting toolbar"
    description="Show formatting controls above the note."
    ><Toggle
      label="Show formatting toolbar"
      checked={preferences.notesToolbar}
      onchange={(value) => setPreference('notesToolbar', value)}
    /></SettingsRow
  >
  <SettingsRow
    title="Keep on Top"
    description="Keep the Notes window above ordinary windows. This is separate from pinning a note in the list."
    ><Toggle
      label="Keep Notes on Top"
      checked={preferences.notesKeepOnTop}
      onchange={(value) => setPreference('notesKeepOnTop', value)}
    /></SettingsRow
  >
</SettingsSection>
{#if preferences.error}<p role="alert">{preferences.error}</p>{/if}

<ToolCommands tool="notes" />
