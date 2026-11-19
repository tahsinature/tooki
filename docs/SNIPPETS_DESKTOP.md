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

Tooki refuses password fields, macOS Secure Input and excluded apps. Where a field exposes writable Accessibility text and selection, expansion replaces the exact trigger directly. Otherwise, terminals and custom-rendered inputs use a keyboard fallback: remove the tracked ASCII trigger with Backspace, then paste the evaluated result with Command-V. Replacement events are tagged to prevent recursive expansion. The fallback leaves the expanded text on the clipboard and excludes this generated clipboard write from Tooki history. It never synthesizes Return; multiline paste behavior is still controlled by the receiving app. Apps that block synthetic input or override Command-V may still require manual paste.

Normal Tooki input fields also support completed snippet expansions. Settings is excluded to keep trigger and configuration editing intact. Within Tooki, a trigger needing arguments remains unchanged; open its matching launcher result to supply arguments rather than replacing the original input surface with an automatic prompt.

When arguments are needed, Tooki captures the original text field and cursor without removing the trigger. Escape cancels. Before direct expansion, Tooki verifies the application, focused field, complete text, and selection again. Keyboard fallback additionally checks for intervening typing, cursor/navigation keys, clicks, scrolling and application switches, retaining focused field/window identity when available. If those changed, it refuses replacement and offers Copy Instead. Direct Accessibility replacement does not modify the clipboard; keyboard fallback uses the clipboard as described above.

Launcher Copy and Paste use the exact prepared preview. Paste captures the previous application when entering Snippets and uses the shared native clipboard paste service. Copy and successful Paste use Tooki's shared launcher dismissal. On unsupported platforms, the local library, evaluator and Copy remain usable; automatic expansion is disabled.

## Storage and extension boundary

The desktop app stores one record per file in `~/.config/tooki/snippets/`. Existing Rust SQLite records and Swift `snippets.json` entries are copied on initial migration, retaining both originals. Unsupported Swift features are preserved as disabled entries with review notes. See [Portable configuration](PORTABLE_CONFIGURATION.md).

Each record separates definitions and personal configuration:

- **Definition:** schema version, stable ID, name, description, collection, snippet kind, template, input schema, required capabilities.
- **Personal configuration:** trigger, enablement, expansion mode, defaults, choice rows and results, saved values.
- **Preferences:** automatic expansion and application exclusions.

This separation supports a future community catalogue without automatically publishing personal email mappings or saved values. Literal text in a template is part of the definition; a future exporter must preview exactly what it will share. Import/export and community installation are not implemented.

The Rust evaluator is pure and bounded. The command service already prepares a result asynchronously before execution, retaining a short-lived ticket so output is not re-evaluated at Copy/Paste time. Future providers can be added at that boundary with explicit capability and credential handling. Unsupported schema versions, unknown fields/operations, and network/script capabilities currently fail validation. HTTP requests, weather providers, arbitrary scripts, and shell execution are deliberately outside this version.

Individual saves are atomic and use content fingerprints to reject stale edits. Duplicate triggers and ambiguous instant prefixes are rejected. The backend is split into model/validation, engine, storage, commands, prepared-result execution, and native expansion. Settings and the launcher share the input and preview components.

## Verification

Run `bun run check`, `bun test`, and `cargo test --manifest-path src-tauri/Cargo.toml --bin tooki` from the repository root.

`make test-snippets-native` verifies the fallback event sequence, recursive-event filtering and pre-deletion failure handling without posting keyboard events. Native smoke checks need real keyboard input. Some UI automation systems send events directly to the target application, bypassing macOS global event taps. Check a direct trigger, a choice suffix, a missing-input prompt, Escape cancellation, changed text/cursor rejection, per-app exclusions, and permission-off behavior in an accessible text field. No tests should type into existing user documents or send messages.
