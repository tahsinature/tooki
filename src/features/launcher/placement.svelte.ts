import { invoke, isTauri } from '@tauri-apps/api/core';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { createDragController } from './dragController';
export const placementState = $state({ error: '' });
export function launcherDrag(element: HTMLElement) {
  if (!isTauri()) return {};
  const controller = createDragController(
    (command, args) => invoke(command, args),
    (error) => {
      placementState.error = `Could not move launcher: ${String(error)}`;
    },
  );
  let pointer: number | undefined;
  function down(e: PointerEvent) {
    if (
      e.button !== 0 ||
      pointer !== undefined ||
      (e.target as Element).closest(
        'input,textarea,button,a,select,[role="button"],[contenteditable="true"]',
      )
    )
      return;
    placementState.error = '';
    if (getCurrentWindow().label !== 'main') {
      void getCurrentWindow()
        .startDragging()
        .catch((error) => {
          placementState.error = String(error);
        });
      return;
    }
    pointer = e.pointerId;
    element.setPointerCapture(pointer);
    controller.start(e.screenX, e.screenY);
  }
  function move(e: PointerEvent) {
    if (e.pointerId === pointer) controller.move(e.screenX, e.screenY);
  }
  function finish(cancelled = false) {
    if (pointer === undefined) return;
    const id = pointer;
    pointer = undefined;
    if (element.hasPointerCapture(id)) element.releasePointerCapture(id);
    void controller.end(cancelled);
  }
  function up() {
    finish();
  }
  function cancel() {
    finish(true);
  }
  function escape(e: KeyboardEvent) {
    if (e.key === 'Escape' && pointer !== undefined) {
      e.preventDefault();
      e.stopPropagation();
      cancel();
    }
  }
  element.addEventListener('pointerdown', down);
  element.addEventListener('pointermove', move);
  element.addEventListener('pointerup', up);
  element.addEventListener('pointercancel', cancel);
  element.addEventListener('lostpointercapture', cancel);
  window.addEventListener('blur', cancel);
  window.addEventListener('keydown', escape, true);
  return {
    destroy() {
      cancel();
      element.removeEventListener('pointerdown', down);
      element.removeEventListener('pointermove', move);
      element.removeEventListener('pointerup', up);
      element.removeEventListener('pointercancel', cancel);
      element.removeEventListener('lostpointercapture', cancel);
      window.removeEventListener('blur', cancel);
      window.removeEventListener('keydown', escape, true);
    },
  };
}
