import { commandAvailable, type AvailabilityMap } from './availability';
import registry from './commands.json';
import { commands, type Item } from '../../lib/data';
import type { AppPreference } from '../launcher/app-preferences.svelte';
// Keep one root entry per tool. Secondary actions appear only for an exact alias.
export function commandItems(
  query: string,
  preferences: Record<string, AppPreference>,
  support: AvailabilityMap = {},
): Item[] {
  const root = commands
    .filter((item) => commandAvailable(item.id, support))
    .map((item) => {
      const command = registry.find((command) => command.root === item.id);
      return {
        ...item,
        alias: command ? preferences[command.id]?.alias : undefined,
      };
    });
  const alias = query.trim().toLowerCase();
  if (!alias) return root;
  return [
    ...root,
    ...registry
      .filter(
        (command) =>
          !command.root &&
          commandAvailable(command.id, support) &&
          preferences[command.id]?.alias.toLowerCase() === alias,
      )
      .map((command): Item => ({
        id: command.id,
        title: command.title,
        subtitle: command.tool,
        kind: 'command',
        group: 'Commands',
        content: '',
        source: '',
        time: '',
        alias: preferences[command.id].alias,
      })),
  ];
}
