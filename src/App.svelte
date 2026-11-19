<script lang="ts">
  import SystemMonitorScreen from './features/system-monitor/SystemMonitorScreen.svelte';
  let systemMonitor = $state(false);
  import EmojiScreen from './features/emoji/EmojiScreen.svelte';
  let emoji = $state(false);
  import SnippetsScreen from './features/snippets/SnippetsScreen.svelte';
  import {
    request as snippetRequest,
    exactResults,
    invocations,
    type Record as SnippetRecord,
    type Library as SnippetLibrary,
    type Arguments,
  } from './features/snippets/api';
  import SystemScreen from './features/system/SystemScreen.svelte';
  import {
    commandSupport,
    loadCommandSupport,
  } from './features/shortcuts/availability.svelte';
  import ClipboardScreen from './features/clipboard/ClipboardScreen.svelte';
  import { tick, onMount } from 'svelte';
  import { listen } from '@tauri-apps/api/event';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import { commandItems } from './features/shortcuts/search';
  import type { Item } from './lib/data';
  import { openNotes } from './features/notes/api';
  import {
    applicationCatalog,
    observeApplications,
    refreshApplications,
  } from './features/launcher/application-catalog.svelte';
  import ApplicationActions from './features/launcher/ApplicationActions.svelte';
  import {
    appPreferences,
    observeAppPreferences,
  } from './features/launcher/app-preferences.svelte';
  import { searchItems } from './features/launcher/search';
  import { nextIndex } from './lib/navigation';
  import SearchHeader from './components/SearchHeader.svelte';
  import PanelLayout from './components/PanelLayout.svelte';
  import ListDetailPanel from './components/ListDetailPanel.svelte';
  import GroupedPanelList from './components/GroupedPanelList.svelte';
  import EmptyState from './components/EmptyState.svelte';
  import ResultRow from './components/ResultRow.svelte';
  import BottomActionBar from './components/BottomActionBar.svelte';
  import ActionsPopup from './components/ActionsPopup.svelte';
  import AppMenu from './components/AppMenu.svelte';
  let appMenu = $state(false);
  import { preferences } from './lib/preferences.svelte';
  import { resizeWindow } from './lib/windowLayout';
  import { themeState, activeTheme } from './lib/themes/store.svelte';
  let snippets = $state(false);
  let snippetRecords = $state<SnippetRecord[]>([]);
  let snippetId = $state('');
  let snippetArguments = $state<Arguments>({});
  async function loadSnippets() {
    snippetRecords = (await snippetRequest<SnippetLibrary>('list')).records;
  }
  let expanded = $state(false);
  let clipboard = $state(false);
  let system = $state(false);
  let systemTarget = $state('command:system.open');
  $effect(() => {
    const view = systemMonitor
      ? 'systemMonitor'
      : emoji
        ? 'emoji'
        : snippets
          ? 'snippets'
          : system
            ? systemTarget === 'command:keepAwake.open'
              ? 'keepAwake'
              : 'system'
            : clipboard
              ? 'clipboard'
              : 'root';
    if (isTauri())
      void invoke('set_launcher_view', { view }).catch(console.error);
  });
  let query = $state('');
  let filter = $state('all');
  let selected = $state(0);
  let actions = $state(false);
  let status = $state('');
  let list = $state<HTMLDivElement>();
  let compact = $derived(
    preferences.compactLauncher &&
      !systemMonitor &&
      !clipboard &&
      !system &&
      !snippets &&
      !emoji &&
      !query &&
      !expanded,
  );
  $effect(() => {
    themeState.selected;
    void resizeWindow(
      compact ? 'compact' : 'expanded',
      activeTheme().tokens.headerHeight,
    ).catch(() => {
      status = 'Window resize failed. Restart Tooki.';
    });
  });
  onMount(() => {
    window.addEventListener('tooki-root-search', back);
    void loadCommandSupport();
    void focusSearch();
    const stopApplications = observeApplications();
    const stopPreferences = observeAppPreferences((error) => (status = error));
    if (!isTauri())
      return () => {
        window.removeEventListener('tooki-root-search', back);
        stopApplications();
        stopPreferences();
      };
    let disposed = false;
    let unlisten: (() => void) | undefined;
    let stopMenu: (() => void) | undefined;
    let stopSnippets: (() => void) | undefined;
    void loadSnippets().catch(console.error);
    void listen(
      'snippets-changed',
      () => void loadSnippets().catch(console.error),
    ).then((stop) => {
      if (disposed) stop();
      else stopSnippets = stop;
    });
    void listen<boolean>(
      'app-menu-visible',
      (event) => (appMenu = event.payload),
    )
      .then((stop) => {
        if (disposed) stop();
        else stopMenu = stop;
      })
      .catch(console.error);
    void listen<number>('launcher-prepare', async ({ payload: revision }) => {
      try {
        back();
        const target = await invoke<string | null>('launcher_request_target', {
          revision,
        });
        if (target) {
          clipboard = false;
          await tick();
          system =
            target.startsWith('command:system.') ||
            target === 'command:keepAwake.open';
          systemTarget = target;
          clipboard = target.startsWith('command:clipboard.');
          snippets = target === 'command:snippets.open';
          emoji = target === 'command:emoji.open';
          systemMonitor = target === 'command:systemMonitor.open';
          filter = target.endsWith('.pinned')
            ? 'pinned'
            : target.endsWith('.links')
              ? 'link'
              : 'all';
          expanded = true;
        }
        await tick();
        await resizeWindow(
          !target && preferences.compactLauncher ? 'compact' : 'expanded',
          activeTheme().tokens.headerHeight,
        );
        await invoke('present_prepared_launcher', { revision });
        void refreshApplications();
      } catch (error) {
        status = String(error);
        await invoke('cancel_launcher_preparation', { revision });
      }
    })
      .then((stop) => {
        if (disposed) stop();
        else {
          unlisten = stop;
          void invoke('launcher_frontend_ready').catch(console.error);
        }
      })
      .catch(console.error);
    return () => {
      window.removeEventListener('tooki-root-search', back);
      disposed = true;
      unlisten?.();
      stopMenu?.();
      stopSnippets?.();
      stopApplications();
      stopPreferences();
    };
  });
  let applications = $derived(
    applicationCatalog.items.map((item) => {
      const preference = appPreferences.values[item.id.slice(4)];
      return {
        ...item,
        pinned: preference?.favorite ?? false,
        alias: preference?.alias ?? '',
        group: preference?.favorite ? 'Favorites' : 'Applications',
      };
    }),
  );
  let visible = $derived(
    searchItems(
      [
        ...commandItems(query, appPreferences.values, commandSupport.values),
        ...applications,
        ...exactResults(query, snippetRecords),
      ],
      query,
      filter,
    ),
  );
  let item = $derived(visible[selected]);
  $effect(() => {
    query;
    filter;
    clipboard;
    selected = 0;
    actions = false;
    status = '';
  });
  $effect(() => {
    selected;
    visible;
    void reveal();
  });
  async function reveal() {
    await tick();
    if (!list) return;
    if (selected === 0) list.scrollTop = 0;
    else if (selected === visible.length - 1)
      list.scrollTop = list.scrollHeight;
    else
      list
        .querySelector<HTMLElement>(`[data-index="${selected}"]`)
        ?.scrollIntoView({ block: 'nearest' });
  }
  async function focusSearch() {
    await tick();
    document.getElementById('search')?.focus();
  }
  function back() {
    selected = 0;
    appMenu = false;
    status = '';
    systemMonitor = false;
    expanded = false;
    clipboard = false;
    system = false;
    snippets = false;
    emoji = false;
    snippetId = '';
    snippetArguments = {};
    query = '';
    filter = 'all';
    actions = false;
    void focusSearch();
  }
  async function primary() {
    if (compact) {
      expanded = true;
      return;
    }
    if (!item) return;
    actions = false;
    if (item.kind === 'application') {
      try {
        await invoke('launch_application', { id: item.id.slice(4) });
        if (isTauri()) await invoke('dismiss_launcher');
      } catch (error) {
        status = String(error);
      }
      return;
    }
    if (item.id === 'systemMonitor') {
      try {
        await invoke('execute_tool_command', {
          id: 'command:systemMonitor.open',
        });
      } catch (error) {
        status = String(error);
      }
      return;
    }
    if (item.id === 'emoji') {
      try {
        await invoke('execute_tool_command', { id: 'command:emoji.open' });
      } catch (error) {
        status = String(error);
      }
      return;
    }
    if (item.id.startsWith('command:')) {
      try {
        await invoke('execute_tool_command', { id: item.id });
      } catch (error) {
        status = String(error);
      }
      return;
    }
    if (item.id.startsWith('snippet:') || item.id === 'snippets') {
      try {
        if (item.id === 'snippets')
          await invoke('execute_tool_command', { id: 'command:snippets.open' });
        else {
          const match = invocations(snippetRecords).find(
            (entry) => entry.trigger === query.trim(),
          );
          await snippetRequest('cancel');
          snippetId = item.id.slice(8);
          snippetArguments = match?.arguments ?? {};
          snippets = true;
          query = '';
        }
      } catch (error) {
        status = String(error);
      }
      return;
    }
    if (!clipboard) {
      if (item.id === 'notes') {
        try {
          await openNotes();
          if (isTauri()) await invoke('dismiss_launcher');
        } catch (error) {
          status = String(error);
        }
        return;
      }
      if (item.id === 'system' || item.id === 'keepAwake') {
        systemTarget =
          item.id === 'keepAwake'
            ? 'command:keepAwake.open'
            : 'command:system.open';
        system = true;
        query = '';
        return;
      }
      if (item.id === 'shelf') {
        try {
          await invoke('execute_tool_command', { id: 'command:shelf.open' });
        } catch (error) {
          status = String(error);
        }
        return;
      }
      if (item.id === 'settings') {
        openSettings();
        return;
      }
      clipboard = true;
      query = '';
      filter = 'all';
      void focusSearch();
      return;
    }
  }
  async function toggleActions(open = !actions) {
    appMenu = false;
    actions = open;
    await tick();
    if (actions)
      document.querySelector<HTMLInputElement>('.actions-search')?.focus();
    else void focusSearch();
  }
  function openSettings() {
    actions = false;
    if (isTauri())
      void invoke('open_settings', {
        page: systemMonitor
          ? 'systemMonitor'
          : emoji
            ? 'emoji'
            : snippets
              ? 'snippets'
              : system
                ? systemTarget === 'command:keepAwake.open'
                  ? 'keepAwake'
                  : 'system'
                : clipboard
                  ? 'clipboard'
                  : 'general',
      }).catch(() => {
        status = 'Could not open Settings.';
      });
    else
      window.open('?window=settings', 'tooki-settings', 'width=800,height=590');
  }
  function keyboard(event: KeyboardEvent) {
    if (
      systemMonitor ||
      clipboard ||
      system ||
      snippets ||
      emoji ||
      event.isComposing
    )
      return;
    const command = event.metaKey || event.ctrlKey;
    if (appMenu || document.querySelector('dialog[open]')) return;
    if (command && event.key === ',') {
      event.preventDefault();
      openSettings();
      return;
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      if (command || !actions) {
        if (isTauri())
          void invoke('dismiss_launcher').catch(
            (error) => (status = String(error)),
          );
        else back();
      } else {
        actions = false;
        void focusSearch();
      }
      return;
    }
    if (compact && ['ArrowDown', 'PageDown'].includes(event.key)) {
      event.preventDefault();
      expanded = true;
      return;
    }
    if (command && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      if (!compact && item) void toggleActions();
      return;
    }
    if (actions) return;
    if ((event.target as HTMLElement)?.tagName === 'SELECT') return;
    if (['ArrowDown', 'ArrowUp', 'PageDown', 'PageUp'].includes(event.key)) {
      event.preventDefault();
      selected = nextIndex(
        event.key,
        selected,
        visible.length,
        Math.max(
          1,
          Math.floor(
            (list?.clientHeight ?? 360) /
              (list?.querySelector<HTMLElement>('.result-row')?.offsetHeight ||
                38),
          ) - 1,
        ),
        command,
      );
    } else if (
      event.key === 'Enter' &&
      (event.target as HTMLElement)?.tagName === 'INPUT'
    ) {
      event.preventDefault();
      void primary();
    }
  }
</script>

<svelte:window onkeydown={keyboard} />
{#if systemMonitor}<SystemMonitorScreen
    onback={back}
    onsettings={openSettings}
  />{:else if emoji}<EmojiScreen
    onback={back}
    onsettings={openSettings}
  />{:else if snippets}<SnippetsScreen
    initialId={snippetId}
    initialArguments={snippetArguments}
    onback={back}
    onsettings={openSettings}
  />{:else if system}<SystemScreen
    tool={systemTarget === 'command:keepAwake.open' ? 'keepAwake' : 'system'}
    initialTarget={systemTarget}
    onback={back}
    onsettings={openSettings}
  />{:else if clipboard}
  <ClipboardScreen
    initialFilter={filter}
    onback={back}
    onsettings={openSettings}
  />
{:else}
  <PanelLayout>
    {#snippet header()}
      <SearchHeader
        bind:query
        bind:filter
        {clipboard}
        onback={back}
        placeholder="Search for apps and commands…"
        filterOptions={compact
          ? undefined
          : [
              { value: 'all', label: 'All' },
              { value: 'favorites', label: 'Favorites' },
              { value: 'application', label: 'Applications' },
              { value: 'command', label: 'Commands' },
            ]}
      />
    {/snippet}
    {#if !compact}<ListDetailPanel>
        <GroupedPanelList
          items={visible}
          group={(row) => (query.trim() ? '' : row.group)}
          label={clipboard ? 'Clipboard items' : 'Commands'}
          bind:element={list}
        >
          {#snippet row(row, index)}
            <ResultRow
              item={row}
              {index}
              selected={index === selected}
              onclick={() => (selected = index)}
              onactions={() => void toggleActions(true)}
              onopen={() => {
                selected = index;
                void primary();
              }}
            />
          {/snippet}
          {#snippet empty()}<EmptyState />{/snippet}
        </GroupedPanelList>
      </ListDetailPanel>{/if}
    {#snippet footer()}
      <BottomActionBar
        {compact}
        appMenuOpen={appMenu}
        onappmenu={(event) => {
          actions = false;
          if (isTauri()) {
            const anchor = (
              event.currentTarget as HTMLElement
            ).getBoundingClientRect();
            void invoke('toggle_app_menu', {
              anchor: { x: anchor.left, y: anchor.top, height: anchor.height },
            }).catch((error) => (status = String(error)));
          } else appMenu = !appMenu;
        }}
        onexpand={() => (expanded = true)}
        {clipboard}
        count={visible.length}
        selectedIndex={selected}
        status={status || applicationCatalog.error}
        primaryLabel={item?.kind === 'application'
          ? 'Open Application'
          : 'Open'}
        onprimary={() => void primary()}
        onactions={() => void toggleActions()}
        disabled={!item}
        onsettings={openSettings}
      />
    {/snippet}
    {#snippet overlay()}
      {#if appMenu && !isTauri()}<AppMenu
          onclose={() => {
            appMenu = false;
            void focusSearch();
          }}
        />{/if}
      {#if actions && item?.kind === 'application'}
        {#key item.id}<ApplicationActions
            {item}
            onopen={() => void primary()}
            onclose={() => {
              actions = false;
              void focusSearch();
            }}
            onstatus={(message) => (status = message)}
          />{/key}
      {:else if actions && item}
        <ActionsPopup
          primaryLabel={item.kind === 'application'
            ? 'Open Application'
            : 'Open command'}
          {clipboard}
          pinned={!!item.pinned}
          oncopy={() => void primary()}
          onpin={() => {}}
          onclose={() => {
            actions = false;
            void focusSearch();
          }}
        />
      {/if}
    {/snippet}
  </PanelLayout>
{/if}
