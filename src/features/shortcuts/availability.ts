import registry from './commands.json';
export type Availability = { available: boolean; reason?: string | null };
export type AvailabilityMap = Record<string, Availability>;
export function commandAvailable(id: string, values: AvailabilityMap): boolean {
  const command = registry.find(
    (entry) => entry.id === id || entry.root === id,
  );
  if (!command?.capability) return true;
  return values[command.id]?.available === true;
}
export function unavailableReason(
  id: string,
  values: AvailabilityMap,
): string | undefined {
  if (commandAvailable(id, values)) return;
  return values[id]?.reason || 'Checking platform support…';
}
