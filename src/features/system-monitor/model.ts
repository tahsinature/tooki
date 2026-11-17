export type View =
  'overview' | 'cpu' | 'memory' | 'storage' | 'power' | 'network';
export const views: { id: View; title: string; keywords: string }[] = [
  {
    id: 'overview',
    title: 'Overview',
    keywords: 'system info mac hostname uptime',
  },
  { id: 'cpu', title: 'CPU', keywords: 'processor cores processes load' },
  {
    id: 'memory',
    title: 'Memory',
    keywords: 'ram pressure swap compressed processes',
  },
  {
    id: 'storage',
    title: 'Storage',
    keywords: 'disk capacity free space read write',
  },
  { id: 'power', title: 'Power', keywords: 'battery charging health cycles' },
  {
    id: 'network',
    title: 'Network',
    keywords: 'internet download upload interface ip',
  },
];
export type Process = {
  pid: number;
  name: string;
  memory: number;
  cpu: number | null;
};
export type Interface = {
  name: string;
  address: string;
  primary: boolean;
  received: number;
  sent: number;
  download: number | null;
  upload: number | null;
};
export type Snapshot = {
  hostname: string;
  os: string;
  model: string;
  chip: string;
  uptime: number;
  physicalCores: number | null;
  logicalCores: number | null;
  performanceCores: number | null;
  efficiencyCores: number | null;
  cpu: { total: number | null; cores: (number | null)[] };
  loadAverage?: number[];
  memoryTotal: number;
  memory?: {
    used: number;
    wired: number;
    compressed: number;
    pressure: number | null;
  };
  swapUsed?: number;
  storage: {
    name?: string;
    format?: string;
    total?: number;
    available?: number;
    readRate?: number | null;
    writeRate?: number | null;
  };
  battery: {
    percent?: number;
    source?: string;
    charging?: boolean;
    remainingSeconds?: number;
    cycles?: number | null;
    health?: number;
  };
  interfaces: Interface[];
  processCount: number;
  topCpu: Process[];
  topMemory: Process[];
};
export type Sample = {
  time: number;
  cpu: number | null;
  memory: number | null;
  download: number | null;
  upload: number | null;
  interface: string;
};
export const bytes = (value: number | null | undefined) =>
  formatBytes(value, 1000, ['B', 'KB', 'MB', 'GB', 'TB']);
export const memoryBytes = (value: number | null | undefined) =>
  formatBytes(value, 1024, ['B', 'KiB', 'MiB', 'GiB', 'TiB']);
function formatBytes(
  value: number | null | undefined,
  base: number,
  units: string[],
): string {
  if (value == null || !Number.isFinite(value)) return 'Unavailable';
  let unit = 0;
  while (Math.abs(value) >= base && unit < units.length - 1) {
    value /= base;
    unit++;
  }
  return `${value.toLocaleString(undefined, { maximumFractionDigits: unit > 1 ? 1 : 0 })} ${units[unit]}`;
}
export const percent = (value: number | null | undefined) =>
  value == null ? 'Sampling…' : `${Math.round(value)}%`;
export const speed = (value: number | null | undefined) =>
  value == null ? 'Sampling…' : `${bytes(value)}/s`;
export function duration(seconds: number | null | undefined) {
  if (seconds == null) return 'Unavailable';
  const minutes = Math.floor(seconds / 60);
  return minutes >= 60
    ? `${Math.floor(minutes / 60)}h ${minutes % 60}m`
    : `${minutes}m`;
}
export function pressure(level: number | null | undefined) {
  return level === 1
    ? 'Normal'
    : level === 2
      ? 'Elevated'
      : level === 4
        ? 'Critical'
        : 'Unavailable';
}
export function appendSample(
  history: Sample[],
  snapshot: Snapshot,
  time = Date.now(),
): Sample[] {
  const network =
    snapshot.interfaces.find((item) => item.primary) ?? snapshot.interfaces[0];
  const sample: Sample = {
    time,
    cpu: snapshot.cpu.total,
    memory: snapshot.memory
      ? (snapshot.memory.used / snapshot.memoryTotal) * 100
      : null,
    download: network?.download ?? null,
    upload: network?.upload ?? null,
    interface: network?.name ?? '',
  };
  const previous = history.at(-1);
  // Never draw a continuous trend across a hidden window or a changed interface.
  const keep =
    previous && time - previous.time <= 10000
      ? history.filter((item) => time - item.time <= 60000)
      : [];
  return [...keep, sample].slice(-31);
}
export function trendPoints(
  values: { time: number; value: number | null }[],
  max: number,
  now: number,
): string[] {
  const paths: string[] = [];
  let path = '';
  for (const point of values) {
    if (point.value == null) {
      if (path) paths.push(path);
      path = '';
      continue;
    }
    const x = Math.max(
      0,
      Math.min(440, ((point.time - now + 60000) / 60000) * 440),
    );
    const y =
      66 - Math.max(0, Math.min(1, point.value / Math.max(1, max))) * 60;
    path += `${path ? ' L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`;
  }
  if (path) paths.push(path);
  return paths;
}

export function pressureTone(level: number | null | undefined) {
  return level === 4 ? 'red' : level === 2 ? 'amber' : 'green';
}
