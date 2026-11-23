import { invoke } from '@tauri-apps/api/core';
import type { Item } from '../../lib/data';
export type Input = {
  key: string;
  label: string;
  kind: 'text' | 'number' | 'choice';
  required: boolean;
};
export type Choice = { key: string; label: string; value: string };
export type Record = {
  definition: {
    schemaVersion: number;
    id: string;
    name: string;
    description: string;
    collection: string;
    kind: 'text' | 'choice' | 'template';
    template: string;
    inputs: Input[];
    capabilities: string[];
  };
  configuration: {
    enabled: boolean;
    automatic: boolean;
    instant: boolean;
    trigger: string;
    defaults: { [key: string]: string };
    choices: { [key: string]: Choice[] };
    values: { [key: string]: string };
  };
  revision: number;
};
export type Library = {
  records: Record[];
  preferences: { automatic: boolean; excludedApps: string[] };
  status: { supported: boolean; permission: boolean; active: boolean };
};
export type Evaluation = {
  text: string | null;
  missing: string[];
  ticket?: number | null;
};
export type Pending = {
  id: string;
  arguments: Arguments;
  context: string;
  error: string;
};
export type Arguments = { [key: string]: string };
export function request<T = void>(
  operation: string,
  args: unknown = {},
): Promise<T> {
  return invoke('snippet_request', { operation, args });
}
export function create(
  kind: Record['definition']['kind'],
  today = false,
): Record {
  return {
    definition: {
      schemaVersion: 1,
      id: crypto.randomUUID(),
      name: today ? 'Today' : '',
      description: '',
      collection: '',
      kind,
      template: today
        ? '{{date}}'
        : kind === 'choice'
          ? '{{lookup:account}}'
          : '',
      inputs:
        kind === 'choice'
          ? [
              {
                key: 'account',
                label: 'Account',
                kind: 'choice',
                required: true,
              },
            ]
          : [],
      capabilities: ['local', 'clock'],
    },
    configuration: {
      enabled: true,
      automatic: true,
      instant: false,
      trigger: today ? '$today' : kind === 'choice' ? '@email' : '',
      defaults: {},
      choices:
        kind === 'choice'
          ? {
              account: [
                { key: '1', label: 'Personal', value: 'email-one@example.com' },
                { key: '2', label: 'Work', value: 'email-two@example.com' },
              ],
            }
          : {},
      values: {},
    },
    revision: 0,
  };
}
export function invocations(
  records: Record[],
): { record: Record; trigger: string; arguments: Arguments }[] {
  return records
    .filter(
      (r) =>
        r.configuration.enabled &&
        r.configuration.trigger &&
        r.definition.schemaVersion === 1,
    )
    .flatMap((record) => {
      const result = [
        {
          record,
          trigger: record.configuration.trigger,
          arguments: {} as Arguments,
        },
      ];
      if (record.definition.kind === 'choice') {
        const key = record.definition.inputs[0]?.key;
        for (const choice of record.configuration.choices[key] ?? [])
          result.push({
            record,
            trigger:
              record.configuration.trigger.replace(/-+$/, '') +
              '-' +
              choice.key,
            arguments: { [key]: choice.key },
          });
      }
      return result;
    });
}
export function row(record: Record): Item {
  return {
    id: `snippet:${record.definition.id}`,
    title: record.definition.name,
    subtitle: record.configuration.trigger || record.definition.description,
    content: record.definition.description,
    kind: 'command',
    group: record.definition.collection || 'Snippets',
    source: 'Snippets',
    time: '',
  };
}
export function exactResults(query: string, records: Record[]): Item[] {
  const exact = invocations(records).find(
    (item) => item.trigger === query.trim(),
  );
  return exact
    ? [
        {
          ...row(exact.record),
          title: `${exact.record.definition.name} · ${exact.trigger}`,
          snippetTrigger: exact.trigger,
        },
      ]
    : [];
}
