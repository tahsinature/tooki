import type { Record } from './api';
// Keep unsaved text when visiting General to reload configuration. The saved
// revision remains attached, so a conflicting external edit cannot be overwritten.
export const snippetDraft = $state<{
  record: Record | undefined;
  baseline: string;
}>({
  record: undefined,
  baseline: '',
});
