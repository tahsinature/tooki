use super::{model::*, storage::Storage};
use crate::config::files;
use serde::Deserialize;
use serde_json::json;
use std::{collections::BTreeMap, path::Path};
#[derive(Deserialize)]
struct SwiftSnippet {
    id: String,
    name: String,
    #[serde(default)]
    collection: String,
    #[serde(default)]
    keyword: String,
    #[serde(default)]
    text: String,
}
// The startup migration marker makes this a one-time import; stable IDs allow retries.
pub fn import_swift(
    root: &Path,
    source: &Path,
    store: &mut Storage,
) -> Result<serde_json::Value, String> {
    let bytes = files::read(source)?.ok_or("Swift snippet file was not found")?;
    let snippets: Vec<SwiftSnippet> = serde_json::from_slice(&bytes).map_err(|e| e.to_string())?;
    let mut existing = store.list()?;
    let mut report = vec![];
    for old in snippets {
        let id = format!("swift-{}", old.id.to_lowercase());
        if existing.iter().any(|r| r.definition.id == id) {
            report.push(json!({"id":id,"name":old.name,"status":"already imported"}));
            continue;
        }
        let mut inputs = vec![];
        let mut notes = vec![];
        let mut template = old.text.clone();
        // Translate only expressions with an equivalent supported meaning.
        template = template
            .replace("{date}", "{{date}}")
            .replace("{time}", "{{time}}");
        while let Some(start) = template.find("{argument:") {
            let Some(end) = template[start..].find('}').map(|i| i + start) else {
                break;
            };
            let key = template[start + 10..end].to_string();
            if !valid_key(&key) {
                notes.push("Unsupported argument name".to_string());
                break;
            }
            if !inputs.iter().any(|i: &Input| i.key == key) {
                inputs.push(Input {
                    key: key.clone(),
                    label: key.clone(),
                    kind: "text".into(),
                    required: true,
                });
            }
            template.replace_range(start..=end, &format!("{{{{input:{key}}}}}"));
        }
        if [
            "{cursor}",
            "{uuid",
            "{date:",
            "{datetime}",
            "{clipboard}",
            "{browser-tab",
            "{snippet ",
        ]
        .iter()
        .any(|token| old.text.contains(token))
        {
            notes.push(
                "Uses Swift placeholders not supported by this engine; original text preserved"
                    .into(),
            );
            template = old.text.clone();
            inputs.clear();
        }
        let accepted_trigger = old.keyword.is_empty()
            || (old.keyword.len() <= 80
                && old.keyword.bytes().all(|b| b.is_ascii_graphic())
                && matches!(old.keyword.as_bytes()[0], b'@' | b'$' | b';' | b':'));
        let trigger = if accepted_trigger {
            old.keyword.clone()
        } else {
            notes.push(format!(
                "Original trigger {:?} needs @, $, ; or : prefix",
                old.keyword
            ));
            String::new()
        };
        let mut record = Record {
            definition: Definition {
                schema_version: 1,
                id: id.clone(),
                name: old.name.clone(),
                description: String::new(),
                collection: old.collection,
                kind: if inputs.is_empty() {
                    "text"
                } else {
                    "template"
                }
                .into(),
                template,
                inputs,
                capabilities: vec!["local".into(), "clock".into()],
            },
            configuration: Configuration {
                enabled: notes.is_empty(),
                automatic: notes.is_empty() && !trigger.is_empty(),
                instant: true,
                trigger,
                defaults: BTreeMap::new(),
                choices: BTreeMap::new(),
                values: BTreeMap::new(),
            },
            revision: 0,
        };
        let mut trial = existing.clone();
        trial.push(record.clone());
        if let Err(error) = validate_conflicts(&trial) {
            notes.push(error);
            record.configuration.enabled = false;
            record.configuration.automatic = false;
        }
        if !notes.is_empty() {
            record.definition.description =
                format!("Imported from Swift. Needs review: {}", notes.join(". "));
        }
        let saved = store.save(record)?;
        existing.push(saved);
        report.push(json!({"id":id,"name":old.name,"status":if notes.is_empty() {"imported"} else {"disabled; needs review"},"notes":notes}));
    }
    let report = json!({"source":source,"items":report});
    let path = root.join("swift-snippet-migration.json");
    let before = files::read(&path)?;
    files::write(&path, &report, before.as_deref())?;
    Ok(report)
}
