# Agent instructions for Tooki

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for building, testing and the project layout.

## UI component names

`design/ui-component-names-sketch.fig` (open it in [OpenPencil](https://openpencil.dev)) is the reference for what each part of the UI is called, for example Root Search, Actions Menu (⌘K), Filter Menu (⌘P), List-Detail Panel and Footer Badge. Each board has numbered pins and a legend with the name, the Swift type and a short note.

- Use these names in code comments, docs, commit messages and conversation. When someone names a component, look it up here first.
- Keep the sketch in sync in the same change whenever you:
  - add a new UI component or panel, or a new part of one,
  - rename or remove a component, or its Swift type,
  - change what a component shows or where it sits enough that the pin or note is wrong.
- Update the pin, the legend entry (name, Swift type, note) and, for a new surface, add a board. Reuse an existing name rather than inventing a second one for the same thing.
- It's a rough sketch, not the real design: grey boxes and placeholder text are fine. Don't chase exact colours, sizes or icons.
- Edit it in the OpenPencil app or with the `openpencil` CLI, and save the file. There's no exported image to keep in sync.
- If the OpenPencil tools aren't available, say so and list the names that need adding or changing, rather than skipping it silently.
