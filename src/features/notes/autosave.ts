import type { Note } from './api';
export type Draft = Pick<
  Note,
  'id' | 'title' | 'document' | 'text' | 'revision'
>;
export type DraftJournal = {
  write: (draft: Draft) => void;
  clear: (id: string) => void;
};

/** One writer per note. Edits during an IPC save are queued with the returned revision. */
export class Autosave {
  private generation = 0;
  private savedGeneration = 0;
  private running: Promise<void> | null = null;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private revision: number;
  private draft: Draft;
  constructor(
    note: Note,
    private write: (draft: Draft) => Promise<Note>,
    private journal: DraftJournal,
    private changed: (
      status: 'saving' | 'saved' | 'error',
      error?: string,
    ) => void,
  ) {
    this.revision = note.revision;
    this.draft = { ...note };
  }
  update(draft: Draft) {
    this.draft = { ...draft, revision: this.revision };
    this.generation++;
    try {
      this.journal.write(this.draft);
    } catch {
      this.changed(
        'error',
        'Recovery storage is unavailable. Saving directly to Notes…',
      );
    }
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      void this.flush().catch(() => {});
    }, 350);
    this.changed('saving');
  }
  flush(): Promise<void> {
    clearTimeout(this.timer);
    if (this.running) return this.running;
    this.running = this.drain().finally(() => {
      this.running = null;
    });
    return this.running;
  }
  private async drain() {
    while (this.savedGeneration < this.generation) {
      const generation = this.generation;
      try {
        const saved = await this.write({
          ...this.draft,
          revision: this.revision,
        });
        this.revision = saved.revision;
        this.draft = { ...this.draft, revision: this.revision };
        this.savedGeneration = generation;
        if (this.savedGeneration === this.generation)
          this.journal.clear(this.draft.id);
        else this.journal.write(this.draft);
      } catch (e) {
        this.changed('error', String(e));
        throw e;
      }
    }
    this.changed('saved');
  }
  get currentRevision() {
    return this.revision;
  }
  dispose() {
    clearTimeout(this.timer);
  }
}
const prefix = 'tooki-notes-draft-v1:';
export const draftJournal: DraftJournal = {
  write: (draft) =>
    localStorage.setItem(prefix + draft.id, JSON.stringify(draft)),
  clear: (id) => localStorage.removeItem(prefix + id),
};
export function readDrafts(): Draft[] {
  const result: Draft[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (key?.startsWith(prefix)) {
      const value = JSON.parse(localStorage.getItem(key)!);
      if (
        typeof value.id !== 'string' ||
        typeof value.title !== 'string' ||
        value.document?.type !== 'doc' ||
        !Number.isInteger(value.revision)
      )
        throw new Error(
          'An unsaved Notes draft could not be read. Recovery data has been kept.',
        );
      result.push(value);
    }
  }
  return result;
}
