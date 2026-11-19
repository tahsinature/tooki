import { matchScore } from '../launcher/search';
export type Emoji = {
  character: string;
  name: string;
  group: string;
  keywords: string[];
  shortcodes: string[];
  shortcode: string;
};
export type Library = {
  items: Emoji[];
  groups: string[];
  recent: string[];
  canPaste: boolean;
};
export type Section = { title: string; items: Emoji[] };
export const columns = 10;

export function sections(
  library: Library,
  query: string,
  filter: string,
): Section[] {
  const byCharacter = new Map(
    library.items.map((item) => [item.character, item]),
  );
  const recent = library.recent.flatMap(
    (character) => byCharacter.get(character) ?? [],
  );
  const items =
    filter === 'recent'
      ? recent
      : library.items.filter(
          (item) => filter === 'all' || item.group === filter,
        );
  const term = query.trim().toLowerCase().replace(/^:|:$/g, '');
  if (query.trim()) {
    const matches = items
      .flatMap((item) => {
        const primary =
          item.character === query.trim()
            ? 110
            : (matchScore(term, item.name) ?? 0);
        const secondary =
          Math.max(
            0,
            ...[...item.keywords, ...item.shortcodes, item.shortcode].map(
              (word) => matchScore(term, word) ?? 0,
            ),
          ) - 5;
        const score = Math.max(primary, secondary);
        return score >= 55 ? [{ item, score }] : [];
      })
      .sort((a, b) => b.score - a.score)
      .map((result) => result.item);
    return matches.length ? [{ title: 'Results', items: matches }] : [];
  }
  const result =
    filter === 'all' || filter === 'recent'
      ? [{ title: 'Recently Used', items: recent }]
      : [];
  if (filter !== 'recent')
    result.push(
      ...library.groups.map((title) => ({
        title,
        items: items.filter((item) => item.group === title),
      })),
    );
  return result.filter((section) => section.items.length);
}

export function gridRows(sections: Section[]) {
  let index = 0;
  return sections.flatMap((section) => {
    const cells = section.items.map((item) => ({
      item,
      index: index++,
      id: `${section.title}/${item.character}`,
    }));
    return Array.from(
      { length: Math.ceil(cells.length / columns) },
      (_, row) => ({
        heading: row === 0 ? section.title : '',
        cells: cells.slice(row * columns, (row + 1) * columns),
      }),
    );
  });
}

export function move(
  rows: ReturnType<typeof gridRows>,
  current: number,
  key: string,
  page: number,
  command: boolean,
) {
  const count = rows.reduce((sum, row) => sum + row.cells.length, 0);
  if (!count || key === 'Home' || (command && key === 'ArrowUp')) return 0;
  if (key === 'End' || (command && key === 'ArrowDown')) return count - 1;
  if (key === 'ArrowLeft' || key === 'ArrowRight')
    return Math.max(
      0,
      Math.min(count - 1, current + (key === 'ArrowLeft' ? -1 : 1)),
    );
  const row = Math.max(
    0,
    rows.findIndex((row) => row.cells.some((cell) => cell.index === current)),
  );
  const column = Math.max(
    0,
    rows[row].cells.findIndex((cell) => cell.index === current),
  );
  const step =
    key === 'PageUp'
      ? -page
      : key === 'PageDown'
        ? page
        : key === 'ArrowUp'
          ? -1
          : 1;
  const target = rows[Math.max(0, Math.min(rows.length - 1, row + step))];
  return target.cells[Math.min(column, target.cells.length - 1)].index;
}
