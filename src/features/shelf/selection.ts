export type Selection = { cursor: string; anchor: string; ids: string[] };
export const emptySelection = (): Selection => ({
  cursor: '',
  anchor: '',
  ids: [],
});
export function selectItem(
  order: string[],
  previous: Selection,
  id: string,
  extend = false,
  toggle = false,
): Selection {
  if (!order.includes(id)) return previous;
  if (extend) {
    return {
      cursor: id,
      anchor: previous.anchor || id,
      ids: [...new Set([...previous.ids, id])],
    };
  }
  return {
    cursor: id,
    anchor: id,
    ids: toggle
      ? previous.ids.includes(id)
        ? previous.ids.filter((value) => value !== id)
        : [...previous.ids, id]
      : [id],
  };
}
