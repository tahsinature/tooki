import { invoke, isTauri } from '@tauri-apps/api/core';
import { writeText } from '@tauri-apps/plugin-clipboard-manager';
export async function copyLog(text: string): Promise<void> {
  if (isTauri()) await writeText(text);
  else await navigator.clipboard.writeText(text);
}
export async function exportLog(
  text: string,
  filename: string,
): Promise<boolean> {
  if (isTauri())
    return invoke<boolean>('export_activity_log', { contents: text, filename });
  const url = URL.createObjectURL(
    new Blob([text], { type: 'application/json' }),
  );
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  return true;
}
