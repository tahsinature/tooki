export type ActivityLogColumn = { id: string; title: string; weight?: number };
export type ActivityLogCell = { text: string; keys?: string[] };
export type ActivityLogEntry = {
  id: string;
  timestamp: number;
  category: string;
  cells: Record<string, ActivityLogCell>;
  details: { label: string; value: string }[];
};
export function filterEntries(
  entries: ActivityLogEntry[],
  query: string,
  category: string,
): ActivityLogEntry[] {
  const terms = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
  return entries.filter((entry) => {
    if (category !== 'all' && entry.category !== category) return false;
    const text = [
      ...Object.values(entry.cells).map((cell) => cell.text),
      ...entry.details.map((detail) => `${detail.label} ${detail.value}`),
    ]
      .join(' ')
      .toLowerCase();
    return terms.every((term) => text.includes(term));
  });
}
export function logText(
  entries: ActivityLogEntry[],
  columns: ActivityLogColumn[],
): string {
  return entries
    .map((entry) =>
      [
        new Date(entry.timestamp).toISOString(),
        ...columns.map(
          (column) => `${column.title}: ${entry.cells[column.id]?.text ?? ''}`,
        ),
        ...entry.details.map((detail) => `${detail.label}: ${detail.value}`),
      ].join('\n'),
    )
    .join('\n\n');
}
export function logJson(
  entries: ActivityLogEntry[],
  columns: ActivityLogColumn[],
): string {
  return JSON.stringify({ version: 1, columns, entries }, null, 2);
}
export function nextRow(
  key: string,
  current: number,
  total: number,
  pageSize: number,
  command: boolean,
): number | null {
  if (!total) return null;
  let next = current;
  if (key === 'Home' || (command && key === 'ArrowUp')) next = 0;
  else if (key === 'End' || (command && key === 'ArrowDown')) next = total - 1;
  else if (key === 'ArrowUp') next--;
  else if (key === 'ArrowDown') next++;
  else if (key === 'PageUp') next -= pageSize;
  else if (key === 'PageDown') next += pageSize;
  else return null;
  return Math.max(0, Math.min(total - 1, next));
}
