import { commandAvailable, type AvailabilityMap } from './availability';
import registry from './commands.json';
import { matchScore } from '../launcher/search';
import { commands, type Item } from '../../lib/data';
import type { AppPreference } from '../launcher/app-preferences.svelte';
// Empty search keeps one entry per tool. Searches expose matching actions.
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
  const actions = registry
    .filter(
      (command) =>
        !command.root &&
        commandAvailable(command.id, support) &&
        (preferences[command.id]?.alias.toLowerCase() === alias ||
          matchScore(query, command.title) !== null),
    )
    .map((command): Item => {
      const parent = commands.find((item) => item.id === command.tool);
      return {
        id: command.id,
        title: command.title,
        parentTitle: parent?.title,
        subtitle: parent ? `${parent.title} / ${command.title}` : command.title,
        kind: 'command',
        group: 'Commands',
        content: '',
        source: '',
        time: '',
        alias: preferences[command.id]?.alias,
      };
    });
  return [
    ...root.filter(
      (item) =>
        matchScore(query, item.title) !== null ||
        item.alias?.toLowerCase() === alias ||
        !actions.some((action) => action.parentTitle === item.title),
    ),
    ...actions,
  ];
}
