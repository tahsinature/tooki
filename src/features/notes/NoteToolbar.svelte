<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import {
    Bold,
    Italic,
    Link,
    List,
    ListOrdered,
    ListChecks,
    Code,
    Quote,
    Heading2,
  } from '@lucide/svelte';
  let {
    editor,
    revision,
    onlink,
  }: { editor: Editor; revision: number; onlink: () => void } = $props();
  const buttons = [
    {
      label: 'Heading',
      icon: Heading2,
      name: 'heading',
      run: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
    },
    {
      label: 'Bold',
      icon: Bold,
      name: 'bold',
      run: () => editor.chain().focus().toggleBold().run(),
    },
    {
      label: 'Italic',
      icon: Italic,
      name: 'italic',
      run: () => editor.chain().focus().toggleItalic().run(),
    },
    { label: 'Link', icon: Link, name: 'link', run: () => onlink() },
    {
      label: 'Bullet list',
      icon: List,
      name: 'bulletList',
      run: () => editor.chain().focus().toggleBulletList().run(),
    },
    {
      label: 'Numbered list',
      icon: ListOrdered,
      name: 'orderedList',
      run: () => editor.chain().focus().toggleOrderedList().run(),
    },
    {
      label: 'Checklist',
      icon: ListChecks,
      name: 'taskList',
      run: () => editor.chain().focus().toggleTaskList().run(),
    },
    {
      label: 'Quote',
      icon: Quote,
      name: 'blockquote',
      run: () => editor.chain().focus().toggleBlockquote().run(),
    },
    {
      label: 'Code block',
      icon: Code,
      name: 'codeBlock',
      run: () => editor.chain().focus().toggleCodeBlock().run(),
    },
  ];
</script>

<div class="note-toolbar" role="toolbar" aria-label="Format note">
  {#each buttons as button}
    <button
      class="icon-button"
      class:active={revision >= 0 && editor.isActive(button.name)}
      aria-label={button.label}
      aria-pressed={editor.isActive(button.name)}
      title={button.label}
      onmousedown={(event) => event.preventDefault()}
      onclick={button.run}><button.icon size={15} /></button
    >
  {/each}
</div>
