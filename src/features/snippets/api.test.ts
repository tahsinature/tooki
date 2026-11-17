import { describe, expect, test } from 'bun:test';
import { create, exactResults, invocations } from './api';
describe('snippet launcher routes', () => {
  test('choice base prompts, suffixes supply the argument', () => {
    const record = create('choice');
    record.definition.name = 'Email';
    const triggers = invocations([record]);
    expect(triggers.map((item) => item.trigger)).toEqual([
      '@email',
      '@email-1',
      '@email-2',
    ]);
    expect(triggers[0].arguments).toEqual({});
    expect(triggers[2].arguments).toEqual({ account: '2' });
    expect(exactResults('@email-2', [record])[0].id).toBe(
      `snippet:${record.definition.id}`,
    );
    expect(exactResults('@email-', [record])).toEqual([]);
    expect(exactResults('@EMAIL-2', [record])).toEqual([]);
  });
  test('disabled and unknown definitions cannot become root commands', () => {
    const record = create('text', true);
    record.configuration.enabled = false;
    expect(exactResults('$today', [record])).toEqual([]);
    record.configuration.enabled = true;
    record.definition.schemaVersion = 2;
    expect(exactResults('$today', [record])).toEqual([]);
  });
  test('starter personal choices are outside the portable definition', () => {
    const record = create('choice');
    expect(JSON.stringify(record.definition)).not.toContain(
      'email-one@example.com',
    );
    expect(record.configuration.choices.account[0].value).toBe(
      'email-one@example.com',
    );
    expect(create('text', true).definition.template).toBe('{{date}}');
  });
});
