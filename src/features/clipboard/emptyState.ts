const filters: Record<string, { title: string; description: string }> = {
  all: {
    title: 'Your clipboard starts here',
    description: 'Copy or drop something to keep it close at hand.',
  },
  dropped: {
    title: 'No dropped items',
    description:
      'Drag files, images, text, or links into this window to add them.',
  },
  unavailable: {
    title: 'No unavailable items',
    description: 'No missing files, folders, or stored images were found.',
  },
  pinned: {
    title: 'No pinned items',
    description: 'Pin an item from its Actions menu to keep it here.',
  },
  text: {
    title: 'No text clips',
    description: 'Copy or drop some text, or choose a different filter.',
  },
  link: {
    title: 'No saved links',
    description: 'Copy or drop a link, or choose a different filter.',
  },
  image: {
    title: 'No image clips',
    description: 'Copy an image, or choose a different filter.',
  },
  file: {
    title: 'No saved files',
    description: 'Copy or drop a file, or choose a different filter.',
  },
  color: {
    title: 'No saved colors',
    description: 'Copy a hex color code, or choose a different filter.',
  },
};

export function clipboardEmptyState(
  query: string,
  filter: string,
  loading = false,
) {
  if (loading)
    return {
      title: 'Loading clipboard…',
      description: 'Getting your saved items ready.',
    };
  if (query.trim())
    return {
      title: 'No matching clips',
      description: 'Try another search or choose a different filter.',
    };
  return filters[filter] ?? filters.all;
}
