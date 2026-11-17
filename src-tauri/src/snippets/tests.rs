use super::{engine::*, model::*, storage::Storage};
use std::collections::BTreeMap;

fn snippet() -> Record {
    Record {
        definition: Definition {
            schema_version: 1,
            id: "greeting".into(),
            name: "Greeting".into(),
            description: String::new(),
            collection: String::new(),
            kind: "template".into(),
            template: "Hello {{input:name | trim | upper}}, {{date}}".into(),
            inputs: vec![Input {
                key: "name".into(),
                label: "Name".into(),
                kind: "text".into(),
                required: true,
            }],
            capabilities: vec!["local".into(), "clock".into()],
        },
        configuration: Configuration {
            enabled: true,
            automatic: true,
            trigger: ";hello".into(),
            ..Default::default()
        },
        revision: 0,
    }
}
fn context() -> Context {
    Context {
        dates: BTreeMap::from([("date".into(), "2026-11-17".into())]),
    }
}
fn arguments(key: &str, value: &str) -> BTreeMap<String, String> {
    BTreeMap::from([(key.into(), value.into())])
}
fn email() -> Record {
    let mut record = snippet();
    record.definition.id = "email".into();
    record.definition.name = "Email".into();
    record.definition.kind = "choice".into();
    record.definition.template = "{{lookup:account}}".into();
    record.definition.inputs = vec![Input {
        key: "account".into(),
        label: "Account".into(),
        kind: "choice".into(),
        required: true,
    }];
    record.configuration.trigger = "@email".into();
    record.configuration.choices.insert(
        "account".into(),
        vec![
            Choice {
                key: "1".into(),
                label: "Personal".into(),
                value: "email-one@mail.com".into(),
            },
            Choice {
                key: "2".into(),
                label: "Work".into(),
                value: "email-two@mail.com".into(),
            },
        ],
    );
    record
}
#[test]
fn date_and_input_are_evaluated_from_one_context() {
    assert_eq!(
        evaluate(&snippet(), &arguments("name", " Ada "), &context())
            .unwrap()
            .text
            .as_deref(),
        Some("Hello ADA, 2026-11-17")
    );
}
#[test]
fn missing_arguments_produce_a_form_without_partial_output() {
    let result = evaluate(&snippet(), &BTreeMap::new(), &context()).unwrap();
    assert!(result.text.is_none());
    assert_eq!(result.missing, ["name"]);
}
#[test]
fn choice_suffixes_share_one_definition_and_resolver() {
    let record = email();
    let triggers = record.invocations();
    assert_eq!(
        triggers
            .iter()
            .map(|i| i.trigger.as_str())
            .collect::<Vec<_>>(),
        ["@email", "@email-1", "@email-2"]
    );
    assert_eq!(
        evaluate(&record, &triggers[2].arguments, &context())
            .unwrap()
            .text
            .as_deref(),
        Some("email-two@mail.com")
    );
    assert_eq!(
        evaluate(&record, &triggers[1].arguments, &context())
            .unwrap()
            .text
            .as_deref(),
        Some("email-one@mail.com")
    );
    assert!(evaluate(&record, &arguments("account", "missing"), &context()).is_err());
}
#[test]
fn values_are_not_recursively_evaluated_or_executed() {
    let mut record = snippet();
    record.configuration.defaults = arguments("name", "{{date}} $(echo secret)");
    assert_eq!(
        evaluate(&record, &BTreeMap::new(), &context())
            .unwrap()
            .text
            .as_deref(),
        Some("Hello {{DATE}} $(ECHO SECRET), 2026-11-17")
    );
}
#[test]
fn optional_input_fallback_and_saved_values() {
    let mut record = snippet();
    record.definition.inputs[0].required = false;
    record.configuration.values = arguments("signature", "Tooki");
    record.definition.template =
        "{{input:name | default:Guest}} · {{value:signature | lower}}".into();
    assert_eq!(
        evaluate(&record, &BTreeMap::new(), &context())
            .unwrap()
            .text
            .as_deref(),
        Some("Guest · tooki")
    );
}
#[test]
fn typed_number_rejects_invalid_and_non_finite_values() {
    let mut record = snippet();
    record.definition.inputs[0].kind = "number".into();
    for invalid in ["abc", "NaN", "inf", "-inf"] {
        assert!(evaluate(&record, &arguments("name", invalid), &context()).is_err());
    }
    assert!(evaluate(&record, &arguments("name", "1.5"), &context())
        .unwrap()
        .text
        .is_some());
}
#[test]
fn unsupported_definitions_and_operations_fail_closed() {
    let mut record = snippet();
    record.definition.schema_version = 2;
    assert!(record.validate().is_err());
    record.definition.schema_version = 1;
    record.definition.capabilities.push("network".into());
    assert!(record.validate().is_err());
    record.definition.capabilities.clear();
    for invalid in [
        "{{input:missing}}",
        "{{input:name | shell}}",
        "{{date",
        "{{http:https://example.com}}",
    ] {
        record.definition.template = invalid.into();
        assert!(record.validate().is_err());
    }
}
#[test]
fn conflicting_triggers_do_not_depend_on_record_order() {
    let a = email();
    let mut b = snippet();
    b.configuration.trigger = "@email-1".into();
    assert!(validate_conflicts(&[a.clone(), b.clone()]).is_err());
    b.configuration.trigger = "@ema".into();
    b.configuration.instant = true;
    assert!(validate_conflicts(&[a.clone(), b.clone()]).is_err());
    assert!(validate_conflicts(&[b.clone(), a.clone()]).is_err());
    b.configuration.instant = false;
    assert!(validate_conflicts(&[a, b]).is_ok());
}
#[test]
fn disabled_snippets_do_not_generate_triggers() {
    let mut record = email();
    record.configuration.enabled = false;
    assert!(record.invocations().is_empty());
}
#[test]
fn instant_choice_base_cannot_steal_its_suffixes() {
    let mut record = email();
    record.configuration.instant = true;
    assert!(validate_conflicts(&[record]).is_err());
}
#[test]
fn sqlite_separates_personal_values_and_guards_stale_edits() {
    let path = std::env::temp_dir().join(format!(
        "tooki-snippets-{}.sqlite3",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let mut store = Storage::open(&path).unwrap();
    assert!(!store.preferences().unwrap().automatic);
    assert!(store.list().unwrap().is_empty());
    let saved = store.save(email()).unwrap();
    assert_eq!(saved.revision, 1);
    let mut changed = saved.clone();
    changed.configuration.choices.get_mut("account").unwrap()[0].value =
        "private@example.com".into();
    let updated = store.save(changed).unwrap();
    assert_eq!(updated.revision, 2);
    assert!(store.save(saved.clone()).is_err());
    assert!(store.delete(&saved.definition.id, saved.revision).is_err());
    let connection = rusqlite::Connection::open(&path).unwrap();
    let definition: String = connection
        .query_row("SELECT body FROM definitions", [], |r| r.get(0))
        .unwrap();
    assert!(!definition.contains("private@example.com"));
    drop(connection);
    drop(store);
    let mut reopened = Storage::open(&path).unwrap();
    assert_eq!(
        reopened.list().unwrap()[0].configuration.choices["account"][0].value,
        "private@example.com"
    );
    reopened
        .delete(&updated.definition.id, updated.revision)
        .unwrap();
    assert!(reopened.list().unwrap().is_empty());
    drop(reopened);
    std::fs::remove_file(path).unwrap();
}
#[test]
fn storage_rejects_duplicate_triggers_atomically() {
    let mut store = Storage::open(std::path::Path::new(":memory:")).unwrap();
    store.save(email()).unwrap();
    let mut duplicate = snippet();
    duplicate.configuration.trigger = "@email-2".into();
    assert!(store.save(duplicate).is_err());
    assert_eq!(store.list().unwrap().len(), 1);
}
