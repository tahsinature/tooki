import type {
  ActivityLogEntry,
  ActivityLogColumn,
} from '../../components/activity-log/model';
import { labels, outcomeTitle, type Check } from './api';
export const logColumns: ActivityLogColumn[] = [
  { id: 'shortcut', title: 'Shortcut', weight: 1.15 },
  { id: 'result', title: 'Result', weight: 1.2 },
  { id: 'owner', title: 'App / assignment', weight: 1.4 },
];
export const logFilters = [
  { value: 'all', label: 'All results' },
  { value: 'lookup', label: 'Lookup' },
  { value: 'delivered', label: 'Reached app' },
  { value: 'intercepted', label: 'Possible interception' },
  { value: 'observed', label: 'Observed' },
];
export function logEntries(
  checks: Check[],
  platform: string,
): ActivityLogEntry[] {
  return checks.map((check) => ({
    id: String(check.id),
    timestamp: check.timestamp,
    category: check.outcome,
    cells: {
      shortcut: {
        text: labels(check.combo, platform).join(' '),
        keys: labels(check.combo, platform),
      },
      result: {
        text:
          (
            {
              delivered: 'Reached app',
              intercepted: 'Possible interception',
              lookup: 'Lookup',
              observed: 'Observed',
            } as Record<string, string>
          )[check.outcome] ?? outcomeTitle(check.outcome),
      },
      owner: {
        text:
          check.matches.map((match) => match.owner).join(', ') ||
          (check.app ? `${check.app} (context)` : 'Not identified'),
      },
    },
    details: [
      { label: 'Result', value: check.detail },
      ...(check.app ? [{ label: 'App context', value: check.app }] : []),
      ...(check.matches.length
        ? check.matches.map((match) => ({
            label: match.owner,
            value: match.detail,
          }))
        : [
            {
              label: 'Assignments',
              value:
                'No known assignment found. This does not mean the shortcut is unused.',
            },
          ]),
    ],
  }));
}
