use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Definition {
    pub schema_version: u32,
    pub id: String,
    pub name: String,
    pub description: String,
    pub collection: String,
    pub kind: String,
    pub template: String,
    pub inputs: Vec<Input>,
    pub capabilities: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Input {
    pub key: String,
    pub label: String,
    pub kind: String,
    pub required: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Choice {
    pub key: String,
    pub label: String,
    pub value: String,
}
/// User data and activation preferences are separate from the portable definition.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Configuration {
    pub enabled: bool,
    pub automatic: bool,
    pub instant: bool,
    pub trigger: String,
    pub defaults: BTreeMap<String, String>,
    pub choices: BTreeMap<String, Vec<Choice>>,
    pub values: BTreeMap<String, String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Record {
    pub definition: Definition,
    pub configuration: Configuration,
    pub revision: i64,
}
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Preferences {
    pub automatic: bool,
    pub excluded_apps: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Invocation {
    pub id: String,
    pub arguments: BTreeMap<String, String>,
    pub trigger: String,
    pub instant: bool,
}
pub fn valid_key(key: &str) -> bool {
    !key.is_empty()
        && key.len() <= 40
        && key.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
}
impl Record {
    pub fn validate(&self) -> Result<(), String> {
        let d = &self.definition;
        let c = &self.configuration;
        if d.schema_version != 1 {
            return Err("This snippet requires a newer definition format.".into());
        }
        if d.capabilities
            .iter()
            .any(|v| !["local", "clock"].contains(&v.as_str()))
        {
            return Err("This snippet requires capabilities this version does not support.".into());
        }
        if d.id.len() > 80 || d.id.is_empty() || d.name.trim().is_empty() || d.name.len() > 200 {
            return Err("Give the snippet a name (up to 200 characters).".into());
        }
        if !["text", "choice", "template"].contains(&d.kind.as_str()) {
            return Err("Unsupported snippet type.".into());
        }
        if d.template.len() > 65536
            || d.inputs.len() > 16
            || d.description.len() > 2000
            || d.collection.len() > 100
        {
            return Err("Snippet exceeds the supported size.".into());
        }
        let mut keys = std::collections::BTreeSet::new();
        for input in &d.inputs {
            if !valid_key(&input.key) || !keys.insert(&input.key) {
                return Err("Input keys must be unique letters, numbers, or underscores.".into());
            }
            if input.label.trim().is_empty()
                || input.label.len() > 100
                || !["text", "number", "choice"].contains(&input.kind.as_str())
            {
                return Err("Each input needs a label and a supported type.".into());
            }
            if input.kind == "choice" {
                let choices = c
                    .choices
                    .get(&input.key)
                    .ok_or("Add choices for each choice input.")?;
                if choices.is_empty() || choices.len() > 100 {
                    return Err("Add between 1 and 100 choices.".into());
                }
                let mut choice_keys = std::collections::BTreeSet::new();
                for row in choices {
                    if !valid_key(&row.key)
                        || !choice_keys.insert(&row.key)
                        || row.label.trim().is_empty()
                        || row.value.len() > 65536
                    {
                        return Err(
                            "Choices need unique keys, labels, and results of at most 64 KB."
                                .into(),
                        );
                    }
                }
            }
        }
        if c.values.len() > 64
            || c.values
                .iter()
                .any(|(k, v)| !valid_key(k) || v.len() > 65536)
        {
            return Err("Saved values need valid keys and must be at most 64 KB.".into());
        }
        let trigger = &c.trigger;
        if !trigger.is_empty()
            && (trigger.len() > 80
                || !trigger.bytes().all(|b| b.is_ascii_graphic())
                || !matches!(trigger.as_bytes()[0], b'@' | b'$' | b';' | b':'))
        {
            return Err("Start the trigger with @, $, ; or :. Use up to 80 ASCII characters without spaces.".into());
        }
        if c.automatic && trigger.is_empty() {
            return Err("Add a trigger to enable automatic expansion.".into());
        }
        if d.kind == "choice" && (d.inputs.len() != 1 || d.inputs[0].kind != "choice") {
            return Err("A choice-list snippet needs one choice input.".into());
        }
        crate::snippets::engine::validate_template(d, c)?;
        Ok(())
    }
    pub fn invocations(&self) -> Vec<Invocation> {
        if !self.configuration.enabled
            || self.configuration.trigger.is_empty()
            || self.validate().is_err()
        {
            return vec![];
        }
        let base = Invocation {
            id: self.definition.id.clone(),
            arguments: BTreeMap::new(),
            trigger: self.configuration.trigger.clone(),
            instant: self.configuration.instant,
        };
        let mut result = vec![base.clone()];
        if self.definition.kind == "choice" {
            let key = &self.definition.inputs[0].key;
            if let Some(rows) = self.configuration.choices.get(key) {
                for row in rows {
                    let mut item = base.clone();
                    item.trigger = format!("{}-{}", base.trigger.trim_end_matches('-'), row.key);
                    item.arguments.insert(key.clone(), row.key.clone());
                    result.push(item);
                }
            }
        }
        result
    }
}
pub fn validate_conflicts(records: &[Record]) -> Result<(), String> {
    let entries: Vec<_> = records.iter().flat_map(Record::invocations).collect();
    for (index, a) in entries.iter().enumerate() {
        for b in &entries[index + 1..] {
            if a.trigger == b.trigger {
                return Err(format!("Trigger {} is already used. Choose a different trigger or disable the other snippet.", a.trigger));
            }
            if (a.instant && b.trigger.starts_with(&a.trigger))
                || (b.instant && a.trigger.starts_with(&b.trigger))
            {
                return Err(
                    "Instant expansion would interrupt a longer trigger. Use Space to expand."
                        .into(),
                );
            }
        }
    }
    Ok(())
}
