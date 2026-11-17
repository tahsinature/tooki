# Agent instructions for Tooki

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for building, testing and the project layout.

## Focused implementation workflow

- Optimize ordinary tasks for a short path from request to verified implementation. Keep investigation and validation proportional to the change.
- For nontrivial work, use one concise discussion covering the recommended approach, the required alternatives and material concerns. Once approved, proceed through routine implementation and verification without requesting approval again. Ask again only for material scope changes, new tradeoffs or required permissions.
- Start with the relevant files and existing implementations. Batch independent searches and reads. Expand investigation only when the evidence requires it; do not repeatedly reread settled context or research established choices.
- Reuse the project's architecture, components and tools. Implement the smallest complete solution, including all affected shared-component consumers. Keep unrelated refactors, dependency changes and architectural improvements separate from the requested work.
- During iteration, run focused checks for the affected behavior. Run required broader checks at completion. Repeat or broaden checks only after relevant changes, failures or unresolved concerns; do not rebuild unchanged code merely for reassurance.
- Reserve profiling, benchmark suites, tooling experiments and installations for tasks that need them. Do not turn ordinary feature work into a tooling or performance project.
- If environment setup or a long-running operation dominates the task, identify that cost early and continue independent useful work. Distinguish setup time from implementation time in updates.
- Finish when the requested behavior and required verification are complete. Report the result and material limitations concisely. Suggest optional improvements separately instead of silently expanding the task.
- Faster execution must preserve correctness, supported behavior, data safety and shared-component consistency. Do not replace necessary verification with assumptions or rushed patches.

## Shared UI components

Shared UI components are the building blocks of Tooki. Every surface that uses the same component must have the same styling, look and interaction behavior.

This includes, but is not limited to:

- Popups: Actions Menu (`ActionsPopup`, `ActionsMenu`) and Filter Menu (`FilterPopup`, `PanelFilterMenu`).
- List-Detail Panel (`ListDetailPanel`), including its shared layout, list, detail area and footer.
- Grouping within lists: `GroupedPanelList`, `PanelListSection` and `SectionHeader`. Group headings must use the same styling wherever they appear, including Root Search, Clipboard, Snippets, Emoji and Shelf.
- Search headers (`SearchHeader`), result rows (`ResultRow`), bottom action bars (`BottomActionBar`), shortcut keycaps (`Keycap`) and shared settings rows and controls.

- Make styling and behavior changes in the shared component and apply them consistently to every consumer, even when the request or screenshot shows only one surface.
- Before changing a shared component, find all its usages and check the impact across those surfaces. Verify every affected consumer after the change.
- Do not add per-surface flags, overrides, variants or duplicate components to preserve different styling or behavior unless the developer explicitly requests that difference. Discuss any necessary exception before implementing it.
- Tool-specific settings may control whether a shared component appears (for example, whether date grouping is enabled). They must not silently change how that component looks or behaves.

## UI component names

`design/ui-component-names-sketch.fig` records UI concepts and their names, not visual design.

- Reuse established component names. Open the sketch only when names are unclear or a conceptual update is needed.
- Update it only for new user-facing UI concepts, concept renames/removals, or core changes to a component's structure or role.
- Do not touch it for styling, spacing, hover effects, tooltips, shortcuts, bug fixes, minor repositioning, or internal Swift helper types.
- When required, edit only the affected pins and legend in OpenPencil or its CLI. Add a board only for a new major surface. Keep it rough, save the `.fig`, and skip exports.
- If OpenPencil is unavailable, report the conceptual update needed.

## Module boundaries

- Put shared panel UI, themes and interaction behavior in `TookiDesignSystem`. Reuse it from every feature and the component gallery.
- Keep feature reducers independent of AppKit and the design system. `ClipboardFeature` is the first reference implementation; native services are supplied through dependencies by the application.
- Keep developer sample data isolated from real configuration, clipboard history and monitoring.
- See [docs/MODERNIZATION.md](docs/MODERNIZATION.md) for migration scope, validation commands and baseline measurements.

## Established tools and reliable implementations

- Proactively recommend popular, mature, well-maintained Swift/macOS libraries and developer tools when they can solve a problem more reliably or efficiently. Do not wait for the developer to ask about tooling.
- Before building custom infrastructure, check the platform APIs, existing project utilities and established open-source solutions. Explain the strongest suitable option, its benefit, integration cost and relevant alternatives during the required discussion before implementation.
- Use the authorized migration to replace fragile behavior, duplicated infrastructure, timing-dependent logic and accumulated workarounds with clearer, supported implementations wherever practical. Include shared components and every consumer in the review.
- Investigate why a workaround exists before removing it. Verify the replacement against the original failure, supported macOS versions, accessibility, keyboard behavior and any affected data formats. A new framework alone is not evidence that a bug is fixed.
- When a compatibility workaround is necessary, document its cause, supported environment and the condition for removing it. Reassess these workarounds when upgrading the toolchain or dependencies, and remove obsolete branches and intermediate debugging patches.
- Choose tools for demonstrated capability and fit, considering maintenance, platform support, licensing, build cost and runtime performance. Popularity and novelty are useful signals, not substitutes for validation.
- Recommend additional tooling whenever it would materially improve development, visual review, testing, profiling or maintenance. Keep developer-only tooling out of release behavior and avoid unnecessary work in the normal development build.
