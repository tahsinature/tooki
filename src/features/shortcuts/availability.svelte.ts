import { invoke, isTauri } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import registry from './commands.json';
import type { AvailabilityMap } from './availability';
export const commandSupport = $state<{ values: AvailabilityMap }>({
  values: {},
});
let loading: Promise<void> | undefined;
let observing = false;
export function loadCommandSupport(refresh = false): Promise<void> {
  if (refresh) loading = undefined;
  if (isTauri() && !observing) {
    observing = true;
    void listen('command-support-changed', () => void loadCommandSupport(true));
  }
  return (loading ??= (async () => {
    try {
      if (!isTauri())
        throw new Error('Tool commands are available in the desktop app only.');
      commandSupport.values = await invoke<AvailabilityMap>(
        'command_availability',
      );
    } catch (error) {
      commandSupport.values = Object.fromEntries(
        registry
          .filter((command) => command.capability)
          .map((command) => [
            command.id,
            { available: false, reason: String(error) },
          ]),
      );
    }
  })());
}
