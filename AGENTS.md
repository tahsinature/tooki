# Agent instructions for Tooki

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for building, testing and the project layout.

## UI component names

`design/ui-component-names-sketch.fig` records UI concepts and their names, not visual design.

- Reuse established component names. Open the sketch only when names are unclear or a conceptual update is needed.
- Update it only for new user-facing UI concepts, concept renames/removals, or core changes to a component's structure or role.
- Do not touch it for styling, spacing, hover effects, tooltips, shortcuts, bug fixes, minor repositioning, or internal Swift helper types.
- When required, edit only the affected pins and legend in OpenPencil or its CLI. Add a board only for a new major surface. Keep it rough, save the `.fig`, and skip exports.
- If OpenPencil is unavailable, report the conceptual update needed.
