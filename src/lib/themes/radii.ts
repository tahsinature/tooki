// One base controls Tooki's corners. Circles and OS-owned window decorations
// deliberately keep their native shape. Older themes retain their two tokens.
export function radiusVariables(base: number) {
  const scaled = (size: number) =>
    `${Math.round(((base * size) / 18) * 100) / 100}px`;
  return {
    '--radius-xs': scaled(2),
    '--radius-small': scaled(4),
    '--radius-control': scaled(6),
    '--radius-row': scaled(8),
    '--radius-card': scaled(10),
    '--radius-window': `${base}px`,
  };
}
