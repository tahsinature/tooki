# Snippets in Tooki Desktop

Create and edit snippets in **Settings → Snippets**. Use the **Snippets** launcher command to preview a saved snippet, supply inputs, copy its result with Return, or paste into the previous application with Command-Return. The command supports the same alias and global-shortcut assignments as other tools.

## Start with a useful example

| Starter | Set up | Use |
| --- | --- | --- |
| Current Date | Save the provided `$today` trigger and `{{date}}` content | Type `$today` followed by Space |
| Text | Give it a name, trigger, and content | Type the trigger followed by Space |
| Choice List | Set the base trigger to `@email`; give keys `1` and `2` their respective email results | `@email-1` and `@email-2` expand directly; `@email` opens a chooser |
| Template with Inputs | Add labeled text, number, or choice inputs; insert their fields into the content | Tooki requests missing required inputs before expanding |

Triggers are case sensitive, begin with `$`, `@`, `;` or `:`, and contain no spaces. Automatic expansion matches a complete token. Space ends the trigger and remains after the expanded text. Optional instant expansion is validated against longer triggers to prevent premature replacement. Choice lists use Space because their base trigger prefixes the generated choices.

**Insert Field** adds date, time, input, lookup, or saved-value tokens without typing their syntax. **Try it** evaluates the draft using the same engine as automatic expansion and the launcher. Previewing never expands text in another app.

## Fields and formatting

- `{{date}}` or `{{date:iso}}`: local date as `YYYY-MM-DD`.
- `{{date:short}}`: `DD/MM/YYYY`; `{{date:long}}`: English month name, day and year.
- `{{time}}`: local 24-hour time; `{{time:12h}}`: local 12-hour time.
- `{{input:name}}`: supplied input text, number, or choice key.
- `{{lookup:account}}`: the result belonging to the selected choice key.
- `{{value:signature}}`: a personal saved value.
- Formatting: `{{input:name | trim | upper}}`, `{{value:email | lower}}`, or `{{input:name | default:Guest}}`.

Inputs may be required or optional, with personal defaults. A required input must be supplied before output is produced. To use a fallback for an empty input, make that input optional. Inserted values are plain text and are never recursively evaluated.

## Expansion and permissions

Automatic expansion is opt-in under **Settings → Snippets**, and requires macOS Accessibility access. Each snippet also has its own enabled and automatic-expansion switches. Excluded application bundle identifiers can be configured in the same page.

Tooki ignores its own windows and secure input, and refuses password fields. Expansion requires an accessible text field exposing its text and selected range, with writable selected text. Unsupported fields remain unchanged. Use the launcher to copy or paste instead. Terminal and custom-rendered editors may not expose the required Accessibility attributes.

When arguments are needed, Tooki captures the original text field and cursor without removing the trigger. Escape cancels. Before expansion, Tooki verifies the application, focused field, complete text, and selection again. If those changed, it refuses replacement and offers Copy Instead. An automatic expansion uses Accessibility text replacement and does not modify the clipboard.

Launcher Copy and Paste use the exact prepared preview. Paste captures the previous application when entering Snippets and uses the shared native clipboard paste service. Copy and successful Paste use Tooki's shared launcher dismissal. On unsupported platforms, the local library, evaluator and Copy remain usable; automatic expansion is disabled.

## Storage and extension boundary

The desktop app owns `snippets/snippets.sqlite3` in its Tauri application-data directory. Existing Swift Tooki snippets are not imported, migrated, edited, or deleted.

Definitions and personal configuration have separate database tables and types:

- **Definition:** schema version, stable ID, name, description, collection, snippet kind, template, input schema, required capabilities.
- **Personal configuration:** trigger, enablement, expansion mode, defaults, choice rows and results, saved values.
- **Preferences:** automatic expansion and application exclusions.

This separation supports a future community catalogue without automatically publishing personal email mappings or saved values. Literal text in a template is part of the definition; a future exporter must preview exactly what it will share. Import/export and community installation are not implemented.

The Rust evaluator is pure and bounded. The command service already prepares a result asynchronously before execution, retaining a short-lived ticket so output is not re-evaluated at Copy/Paste time. Future providers can be added at that boundary with explicit capability and credential handling. Unsupported schema versions, unknown fields/operations, and network/script capabilities currently fail validation. HTTP requests, weather providers, arbitrary scripts, and shell execution are deliberately outside this version.

Saves are transactional and use revisions to reject stale edits. Duplicate triggers and ambiguous instant prefixes are rejected. The backend is split into model/validation, engine, storage, commands, prepared-result execution, and native expansion. Settings and the launcher share the input and preview components.

## Verification

Run `bun run check`, `bun test`, and `cargo test --manifest-path src-tauri/Cargo.toml --bin tooki` from the repository root.

Native smoke checks need real keyboard input. Some UI automation systems send events directly to the target application, bypassing macOS global event taps. Check a direct trigger, a choice suffix, a missing-input prompt, Escape cancellation, changed text/cursor rejection, per-app exclusions, and permission-off behavior in an accessible text field. No tests should type into existing user documents or send messages.
