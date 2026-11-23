import type { Item } from '../../lib/data';
const normalize = (value: string) =>
  value.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().trim();
// Same match tiers as TookiKit.FuzzyMatch. Title matches outrank tool keywords.
export function matchScore(query: string, title: string): number | null {
  query = normalize(query);
  title = normalize(title);
  if (!query) return 0;
  if (title === query) return 100;
  if (title.startsWith(query)) return 90;
  const words = title.split(/[\s_.-]+/);
  if (words.some((word) => word.startsWith(query))) return 80;
  if (
    words
      .map((word) => word[0] ?? '')
      .join('')
      .startsWith(query)
  )
    return 70;
  if (title.includes(query)) return 60;
  if (title.length <= 40) {
    let index = 0;
    for (const character of title) if (character === query[index]) index++;
    if (index === query.length) return 30;
  }
  return null;
}
export function searchItems(
  items: Item[],
  query: string,
  filter: string,
): Item[] {
  return items
    .flatMap((item) => {
      if (filter === 'favorites') {
        if (item.kind !== 'application' || !item.pinned) return [];
      } else if (filter !== 'all' && item.kind !== filter) return [];
      const score =
        (item.id.startsWith('snippet:') && item.snippetTrigger === query.trim()
          ? 110
          : matchScore(query, item.title)) ??
        (query.trim() && normalize(item.content).includes(normalize(query))
          ? 10
          : null);
      return score === null ? [] : [{ item, score }];
    })
    .sort(
      (a, b) =>
        b.score - a.score ||
        Number(!!b.item.pinned) - Number(!!a.item.pinned) ||
        Number(a.item.kind === 'application') -
          Number(b.item.kind === 'application') ||
        a.item.title.localeCompare(b.item.title),
    )
    .map((result) => result.item);
}
