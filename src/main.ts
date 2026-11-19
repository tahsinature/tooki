import { mount } from 'svelte';
import App from './App.svelte';
import SettingsScreen from './features/settings/SettingsScreen.svelte';
import ComponentGallery from './ComponentGallery.svelte';
import './style.css';
import './settings.css';
import './features/clipboard/clipboard.css';
import { initializeThemes } from './lib/themes/store.svelte';
import { initializePreferences } from './lib/preferences.svelte';
import { disableBrowserContextMenu } from './lib/contextMenu';
const cleanupContextMenu = disableBrowserContextMenu();
const isGuides =
  new URLSearchParams(location.search).get('window') === 'snap-guides';
const cleanupThemes = isGuides ? () => {} : initializeThemes();
const cleanupPreferences = isGuides ? () => {} : initializePreferences();
if (import.meta.hot)
  import.meta.hot.dispose(() => {
    cleanupThemes();
    cleanupPreferences();
    cleanupContextMenu();
  });
const component =
  import.meta.env.DEV && new URLSearchParams(location.search).has('gallery')
    ? ComponentGallery
    : new URLSearchParams(location.search).get('window') === 'settings'
      ? SettingsScreen
      : App;
if (new URLSearchParams(location.search).get('window') === 'filter-popup') {
  void import('./components/FilterPopupWindow.svelte').then(
    ({ default: Popup }) =>
      mount(Popup, { target: document.getElementById('app')! }),
  );
} else if (new URLSearchParams(location.search).get('window') === 'app-menu') {
  void import('./features/launcher/AppMenuWindow.svelte').then(
    ({ default: AppMenuWindow }) =>
      mount(AppMenuWindow, { target: document.getElementById('app')! }),
  );
} else if (new URLSearchParams(location.search).get('window') === 'notes') {
  void import('./features/notes/NotesWindow.svelte').then(
    ({ default: Notes }) =>
      mount(Notes, { target: document.getElementById('app')! }),
  );
} else if (isGuides) {
  void import('./features/launcher/SnapGuides.svelte').then(
    ({ default: Guides }) =>
      mount(Guides, { target: document.getElementById('app')! }),
  );
} else mount(component, { target: document.getElementById('app')! });
