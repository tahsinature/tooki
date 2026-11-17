export function nextIndex(
  key: string,
  current: number,
  count: number,
  page: number,
  command = false,
): number {
  if (!count) return 0;
  if (key === 'Home' || (command && key === 'ArrowUp')) return 0;
  if (key === 'End' || (command && key === 'ArrowDown')) return count - 1;
  const delta =
    key === 'PageDown'
      ? page
      : key === 'PageUp'
        ? -page
        : key === 'ArrowDown'
          ? 1
          : key === 'ArrowUp'
            ? -1
            : 0;
  return Math.max(0, Math.min(count - 1, current + delta));
}
