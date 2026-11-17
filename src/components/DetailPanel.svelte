<script lang="ts">
  import DetailLayout from './DetailLayout.svelte';
  import InformationList from './InformationList.svelte';
  import {
    FileText,
    Link,
    Code,
    Pin,
    Image,
    Folder,
    Palette,
  } from '@lucide/svelte';
  import type { Item } from '../lib/data';
  let { item }: { item: Item } = $props();
  const icons = {
    text: FileText,
    link: Link,
    code: Code,
    application: Folder,
    command: FileText,
    image: Image,
    file: Folder,
    color: Palette,
  };
  let Icon = $derived(icons[item.kind]);
</script>

<DetailLayout label="Clipboard preview">
  <div class="preview-heading">
    <span class="eyebrow">PREVIEW</span>{#if item.pinned}<span class="pin-label"
        ><Pin size={12} /> Pinned</span
      >{/if}
  </div>
  <div class="document-preview" class:code-preview={item.kind === 'code'}>
    <Icon size={25} strokeWidth={1.3} />
    <pre>{item.content}</pre>
  </div>
  {#snippet information()}
    <InformationList
      entries={[
        {
          label: 'Type',
          value:
            item.kind === 'code'
              ? 'Code'
              : item.kind === 'link'
                ? 'Link'
                : 'Text',
        },
        { label: 'Characters', value: item.content.length },
        { label: 'Source', value: item.source },
        { label: 'Copied', value: item.time },
      ]}
    />
  {/snippet}
</DetailLayout>
