import { test, expect } from 'bun:test';
import {
  appendSample,
  bytes,
  memoryBytes,
  pressure,
  trendPoints,
  type Snapshot,
} from './model';
const snapshot = {
  cpu: { total: 36, cores: [36] },
  memoryTotal: 100,
  memory: { used: 80, pressure: 1 },
  interfaces: [{ name: 'en0', primary: true, download: 100, upload: 20 }],
} as Snapshot;
test('memory pressure is independent of utilization and unknown values stay unknown', () => {
  expect(pressure(snapshot.memory?.pressure)).toBe('Normal');
  expect(pressure(2)).toBe('Elevated');
  expect(pressure(4)).toBe('Critical');
  expect(pressure(null)).toBe('Unavailable');
  expect(bytes(undefined)).toBe('Unavailable');
  expect(bytes(0)).toBe('0 B');
  expect(memoryBytes(16 * 1024 ** 3)).toBe('16 GiB');
  expect(bytes(500 * 1000 ** 3)).toBe('500 GB');
});
test('history is bounded to a minute and resets after a sampling gap', () => {
  let history = appendSample([], snapshot, 0);
  for (let time = 2000; time <= 100000; time += 2000)
    history = appendSample(history, snapshot, time);
  expect(history).toHaveLength(31);
  expect(history[0].time).toBe(40000);
  expect(appendSample(history, snapshot, 120000)).toHaveLength(1);
});
test('trend paths preserve missing samples rather than inventing zero readings', () => {
  expect(
    trendPoints(
      [
        { time: 0, value: 50 },
        { time: 2000, value: null },
        { time: 4000, value: 100 },
      ],
      100,
      60000,
    ),
  ).toEqual(['M0.0,36.0', 'M29.3,6.0']);
});
