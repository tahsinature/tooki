<script lang="ts">
  import SystemMonitorSettings from '../system-monitor/SystemMonitorSettings.svelte';
  import { Activity } from '@lucide/svelte';
  import { getVersion } from '@tauri-apps/api/app';
  let version = $state('0.12.0');
  onMount(() => {
    if (isTauri()) void getVersion().then((value) => (version = value));
  });
  import ToolCommands from '../shortcuts/ToolCommands.svelte';
  import SnippetsSettings from '../snippets/SnippetsSettings.svelte';
  import KeepAwakeSettings from '../keep-awake/KeepAwakeSettings.svelte';
  import SystemSettings from '../system/SystemSettings.svelte';
  import { loadCommandSupport } from '../shortcuts/availability.svelte';
  import ShortcutsSettings from '../shortcuts/ShortcutsSettings.svelte';
  import { observeAppPreferences } from '../launcher/app-preferences.svelte';
  import { observeApplications } from '../launcher/application-catalog.svelte';
  import { observeLauncherAssignment } from '../shortcuts/assignments.svelte';
  import GeneralSettings from './GeneralSettings.svelte';
  import ApplicationsSettings from './ApplicationsSettings.svelte';
  import NotesSettings from '../notes/NotesSettings.svelte';
  import SearchField from '../../components/SearchField.svelte';
  import {
    Smile,
    TextCursorInput,
    AppWindow,
    ChevronLeft,
    ChevronRight,
    Palette,
    ClipboardList,
    Info,
    Command,
    Settings,
    Keyboard,
    NotebookPen,
    ScanSearch,
    Power,
    Coffee,
    Zap,
    Layers,
  } from '@lucide/svelte';
  import appIcon from '../../../src-tauri/icons/icon.png';
  import ClipboardSettings from '../clipboard/ClipboardSettings.svelte';
  import { onMount, tick } from 'svelte';
  import { nextIndex } from '../../lib/navigation';
  import { listen } from '@tauri-apps/api/event';
  import ShelfSettings from '../shelf/ShelfSettings.svelte';
  import HyperSettings from '../hyper/HyperSettings.svelte';
  import DetectiveSettings from '../detective/DetectiveSettings.svelte';
  import AppearanceSettings from './AppearanceSettings.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';
  import Toggle from '../../components/Toggle.svelte';
  import Keycap from '../../components/Keycap.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import { preferences, setPreference } from '../../lib/preferences.svelte';
  import { isTauri } from '@tauri-apps/api/core';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  async function keyboard(event: KeyboardEvent) {
    if (event.defaultPrevented || event.isComposing) return;
    if (
      event.altKey &&
      !event.metaKey &&
      !event.ctrlKey &&
      !event.shiftKey &&
      ['ArrowUp', 'ArrowDown'].includes(event.key)
    ) {
      if (
        document.querySelector(
          'dialog[open], .shortcut-record-button[aria-pressed="true"]',
        )
      )
        return;
      event.preventDefault();
      const visible = matches.filter(
        (item) => item.group === 'App' || item.group === 'Tools',
      );
      if (!visible.length) return;
      const current = visible.findIndex((item) => item.id === page);
      const index =
        current < 0
          ? event.key === 'ArrowDown'
            ? 0
            : visible.length - 1
          : nextIndex(event.key, current, visible.length, 1);
      navigate(visible[index].id);
      await tick();
      const row = document.querySelector<HTMLButtonElement>(
        '.settings-sidebar nav button[aria-current="page"]',
      );
      row?.focus({ preventScroll: true });
      row?.scrollIntoView({ block: 'nearest' });
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'w') {
      event.preventDefault();
      if (isTauri()) void getCurrentWindow().close();
      else window.close();
    }
  }
  let history = $state(['general']);
  let historyIndex = $state(0);
  let page = $derived(history[historyIndex]);
  function navigate(id: string) {
    if (id === page) return;
    history = [...history.slice(0, historyIndex + 1), id];
    historyIndex = history.length - 1;
  }
  function go(offset: number) {
    search = '';
    historyIndex = Math.max(
      0,
      Math.min(history.length - 1, historyIndex + offset),
    );
  }
  onMount(() => {
    void loadCommandSupport();
    const stopAssignments = observeAppPreferences();
    const stopLauncher = observeLauncherAssignment();
    const stopApps = observeApplications();
    let disposed = false;
    let stop: (() => void) | undefined;
    void listen<string>('settings-page', (event) => {
      search = '';
      navigate(event.payload);
    }).then((fn) => {
      if (disposed) fn();
      else stop = fn;
    });
    return () => {
      disposed = true;
      stopAssignments();
      stopLauncher();
      stopApps();
      stop?.();
    };
  });
  let search = $state('');
  const pages = [
    {
      id: 'general',
      title: 'General',
      icon: Settings,
      group: 'App',
      tone: 'general',
      keywords:
        'launcher navigation shortcut hotkey startup login menu bar tray',
    },
    {
      id: 'applications',
      title: 'Applications',
      icon: AppWindow,
      group: 'App',
      tone: 'applications',
      keywords: 'apps catalog refresh favorites alias shortcuts',
    },
    {
      id: 'shortcuts',
      title: 'Shortcuts',
      icon: Keyboard,
      group: 'App',
      tone: 'shortcuts',
      keywords: 'customized commands alias hotkey keyboard assignments',
    },
    {
      id: 'appearance',
      title: 'Appearance',
      icon: Palette,
      group: 'App',
      tone: 'appearance',
      keywords: 'theme color style import export system window mode compact',
    },
    {
      id: 'hyper',
      title: 'Hyper Key',
      icon: Zap,
      group: 'App',
      tone: 'hyper',
      keywords: 'caps lock keyboard remap modifiers linux helper',
    },
    {
      id: 'detective',
      title: 'Shortcut Detective',
      icon: ScanSearch,
      group: 'Tools',
      tone: 'detective',
      keywords: 'keyboard hotkey conflict intercept listen shortcuts',
    },
    {
      id: 'notes',
      title: 'Notes',
      icon: NotebookPen,
      group: 'Tools',
      tone: 'notes',
      keywords: 'writing formatting toolbar keep on top',
    },
    {
      id: 'shelf',
      title: 'Shelferry',
      icon: Layers,
      group: 'Tools',
      tone: 'shelf',
      keywords: 'extension shelf floating files drag drop copies references',
    },
    {
      id: 'emoji',
      title: 'Emoji',
      icon: Smile,
      group: 'Tools',
      tone: 'awake',
      keywords: 'emoji picker symbols recent copy paste shortcode',
    },
    {
      id: 'snippets',
      title: 'Snippets',
      icon: TextCursorInput,
      group: 'Tools',
      tone: 'appearance',
      keywords: 'text expansion template choice email date automatic',
    },
    {
      id: 'clipboard',
      title: 'Clipboard',
      icon: ClipboardList,
      group: 'Tools',
      tone: 'clipboard',
      keywords: 'group date position remember history',
    },
    {
      id: 'keepAwake',
      title: 'Keep Awake',
      icon: Coffee,
      group: 'Tools',
      tone: 'awake',
      keywords: 'wake lock caffeine coffee display sleep menu bar icon',
    },
    {
      id: 'systemMonitor',
      title: 'System Monitor',
      icon: Activity,
      group: 'Tools',
      tone: 'monitor',
      keywords:
        'cpu memory ram storage disk power battery network performance activity',
    },
    {
      id: 'system',
      title: 'System Actions',
      icon: Power,
      group: 'Tools',
      tone: 'system',
      keywords: 'sleep empty trash eject disks commands platform',
    },
    {
      id: 'about',
      title: 'About',
      icon: Info,
      group: '',
      tone: 'about',
      keywords: 'version prototype',
    },
  ];
  let matches = $derived(
    pages.filter((item) =>
      `${item.title} ${item.keywords}`
        .toLowerCase()
        .includes(search.toLowerCase()),
    ),
  );
  let current = $derived(pages.find((item) => item.id === page)!);
  $effect(() => {
    if (matches.length && !matches.some((item) => item.id === page))
      navigate(matches[0].id);
  });
</script>

<svelte:window onkeydown={keyboard} />
<main class="app-shell settings-shell">
  {#if !/Mac/.test(navigator.platform)}<div class="settings-window-controls">
      <button
        class="icon-button"
        aria-label="Close Settings"
        onclick={() => {
          if (isTauri()) void getCurrentWindow().close();
        }}>×</button
      >
      <button
        class="icon-button"
        aria-label="Minimize Settings"
        onclick={() => {
          if (isTauri()) void getCurrentWindow().minimize();
        }}>−</button
      >
    </div>{/if}
  <aside class="settings-sidebar">
    <div class="settings-window-drag" data-tauri-drag-region></div>
    <SearchField
      label="Search settings"
      placeholder="Search settings…"
      bind:value={search}
    />
    <button
      class="settings-brand"
      onclick={() => {
        search = '';
        navigate('about');
      }}
      aria-current={page === 'about' ? 'page' : undefined}
      aria-label="About Tooki"
      ><img src={appIcon} alt="" /><strong>Tooki</strong><span
        class="settings-version">v{version}</span
      ></button
    >
    <nav aria-label="Settings pages">
      {#each ['App', 'Tools'] as group}
        {#if matches.some((entry) => entry.group === group)}
          <div class="settings-nav-group">
            {#if group}<span class="sidebar-label">{group}</span>{/if}
            {#each matches.filter((entry) => entry.group === group) as entry}
              <button
                class:active={page === entry.id}
                aria-current={page === entry.id ? 'page' : undefined}
                onclick={() => navigate(entry.id)}
                ><span class="sidebar-icon {entry.tone}"
                  ><entry.icon size={15} /></span
                >{entry.title}</button
              >
            {/each}
          </div>
        {/if}
      {/each}
    </nav>
  </aside>
  <div class="settings-main">
    <header class="settings-toolbar" data-tauri-drag-region>
      <div class="settings-history">
        <button
          aria-label="Previous settings page"
          disabled={historyIndex === 0}
          onclick={() => go(-1)}><ChevronLeft size={17} /></button
        ><button
          aria-label="Next settings page"
          disabled={historyIndex === history.length - 1}
          onclick={() => go(1)}><ChevronRight size={17} /></button
        >
      </div>
      <span>{current.title}</span>
    </header>
    <div class="settings-content">
      <div class="settings-content-body">
        {#if !matches.length}<EmptyState
            title="No matching settings"
            description="Try searching for themes, clipboard, or appearance."
          />
        {:else if page === 'general'}<GeneralSettings />
        {:else if page === 'applications'}<ApplicationsSettings />
        {:else if page === 'shortcuts'}<ShortcutsSettings />
        {:else if page === 'appearance'}<AppearanceSettings />
        {:else if page === 'hyper'}<HyperSettings />
        {:else if page === 'detective'}<DetectiveSettings />
        {:else if page === 'keepAwake'}<KeepAwakeSettings />
        {:else if page === 'systemMonitor'}<SystemMonitorSettings />
        {:else if page === 'system'}<SystemSettings />
        {:else if page === 'notes'}<NotesSettings />
        {:else if page === 'shelf'}<ShelfSettings />
        {:else if page === 'emoji'}<ToolCommands tool="emoji" />
        {:else if page === 'snippets'}<SnippetsSettings />
        {:else if page === 'clipboard'}
          <SettingsSection title="Browsing">
            <SettingsRow
              title="Group by date"
              description="Show date headings. Pinned items always stay separate."
              ><Toggle
                label="Group by date"
                checked={preferences.groupByDate}
                onchange={(value) => setPreference('groupByDate', value)}
              /></SettingsRow
            >
            <SettingsRow
              title="Remember position"
              description="Restore the selected clip when returning to Clipboard."
              ><Toggle
                label="Remember position"
                checked={preferences.rememberPosition}
                onchange={(value) => setPreference('rememberPosition', value)}
              /></SettingsRow
            >
          </SettingsSection>
          <SettingsSection title="Keyboard navigation">
            <SettingsRow title="Return to root search"
              ><Keycap text="⌘" /><Keycap text="Esc" /></SettingsRow
            >
            <SettingsRow title="First / last item"
              ><Keycap text="⌘" /><Keycap text="↑ / ↓" /></SettingsRow
            >
            <SettingsRow title="Previous / next page"
              ><Keycap text="Page Up / Down" /></SettingsRow
            >
          </SettingsSection>
          <ClipboardSettings />
          <p class="settings-message" role="status">{preferences.error}</p>
        {:else}
          <div class="about-identity">
            <span class="settings-app-icon"><Command size={32} /></span>
            <h1>Tooki</h1>
            <p>Version {version}</p>
          </div>
          <SettingsSection title="Built with"
            ><SettingsRow title="Desktop runtime">Tauri · Rust</SettingsRow
            ><SettingsRow title="Interface">Svelte · TypeScript</SettingsRow
            ></SettingsSection
          >
          <p class="settings-note">
            A keyboard-first launcher with clipboard history, snippets, emoji,
            notes, and native macOS tools. Updates are available through
            Homebrew.
          </p>
        {/if}
      </div>
    </div>
  </div>
</main>
