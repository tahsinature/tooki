type SearchableNote = { title: string; text: string };
export function noteTitle(note: SearchableNote): string {
  return (
    note.title ||
    Array.from(note.text.split('\n').find((line) => line.trim()) ?? '')
      .slice(0, 80)
      .join('') ||
    'Untitled note'
  );
}
export function matchesNote(note: SearchableNote, query: string): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle || note.text.toLowerCase().includes(needle)) return true;
  const remaining = Array.from(needle);
  let index = 0;
  for (const character of noteTitle(note).toLowerCase()) {
    if (character === remaining[index]) index++;
  }
  return index === remaining.length;
}
