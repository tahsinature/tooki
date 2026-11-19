<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke, isTauri } from '@tauri-apps/api/core';
  import appIcon from '../../../src-tauri/icons/icon.png';
  import UpdateCheck from './UpdateCheck.svelte';
  import DevelopmentBadge from '../../components/DevelopmentBadge.svelte';
  import SettingsSection from '../../components/settings/SettingsSection.svelte';
  import SettingsRow from '../../components/settings/SettingsRow.svelte';

  type BuildInfo = {
    name: string;
    version: string;
    builtAt: number;
    buildNumber: string;
    development: boolean;
    installUnavailable: string | null;
  };
  let { version }: { version: string } = $props();
  let build = $state<BuildInfo | null>(null);
  let error = $state('');
  const dateFormat = new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'long',
  });
  onMount(() => {
    if (isTauri())
      void invoke<BuildInfo>('build_info')
        .then((value) => {
          build = value;
        })
        .catch(() => {
          error = 'Build information is unavailable.';
        });
  });
</script>

<div class="about-settings">
  <header class="about-header">
    <img src={appIcon} alt="" width="76" height="76" />
    <div>
      <div class="about-name">
        <h1>Tooki</h1>
        {#if build?.development}<DevelopmentBadge />{/if}
      </div>
      <p>
        Version {build?.version ?? version}{#if build?.buildNumber}
          <span>· Build {build.buildNumber}</span>{/if}
      </p>
      <p class="build-date">
        {#if build?.builtAt}Built {dateFormat.format(
            new Date(build.builtAt * 1000),
          )}{:else}{error || 'Loading build information…'}{/if}
      </p>
    </div>
  </header>
  <UpdateCheck
    installUnavailable={build
      ? build.installUnavailable
      : 'Loading build information…'}
  />
  <p class="about-description">
    Your apps, ideas, and everyday tools. One shortcut away.
  </p>
  <details>
    <summary>Technical details</summary>
    <SettingsSection>
      <SettingsRow title="Desktop runtime">Tauri · Rust</SettingsRow>
      <SettingsRow title="Interface">Svelte · TypeScript</SettingsRow>
      <SettingsRow title="Updates">Signed releases · Homebrew</SettingsRow>
    </SettingsSection>
  </details>
</div>

<style>
  .about-settings {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 12px 0;
  }
  .about-header {
    display: flex;
    align-items: center;
    gap: 20px;
    padding: 8px 0 12px;
  }
  .about-header img {
    flex: none;
    border-radius: 22%;
  }
  .about-name {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  h1 {
    font-size: 25px;
    font-weight: 650;
    letter-spacing: -0.7px;
    margin: 0 0 5px;
  }
  .about-header p {
    margin: 0;
    color: var(--muted);
    font-size: 13px;
    line-height: 1.7;
  }
  .about-header .build-date {
    font-size: 11px;
    margin-top: 4px;
  }
  .about-description {
    color: var(--muted);
    font-size: 12px;
    margin: 0;
    line-height: 1.6;
  }
  details {
    border-top: 1px solid var(--line);
    padding-top: 18px;
  }
  summary {
    color: var(--muted);
    font-size: 12px;
    cursor: pointer;
    margin-bottom: 14px;
  }
</style>
