import type { Node } from '@tiptap/pm/model';
export function findMatches(
  doc: Node,
  query: string,
): { from: number; to: number }[] {
  if (!query) return [];
  const matches: { from: number; to: number }[] = [];
  doc.descendants((node, pos) => {
    if (!node.isTextblock) return true;
    let text = '';
    const positions: number[] = [];
    node.descendants((child, offset) => {
      if (child.isText) {
        text += child.text;
        for (let i = 0; i < child.nodeSize; i++)
          positions.push(pos + 1 + offset + i);
      } else if (child.isLeaf) {
        text += '\n';
        positions.push(pos + 1 + offset);
      }
    });
    // Match the original string so Unicode case conversion cannot shift positions.
    const pattern = new RegExp(
      query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'),
      'giu',
    );
    for (const match of text.matchAll(pattern)) {
      const index = match.index;
      matches.push({
        from: positions[index],
        to: positions[index + match[0].length - 1] + 1,
      });
    }
    return false;
  });
  return matches;
}
