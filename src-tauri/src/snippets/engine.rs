//! Pure, bounded local evaluation. No scripts, recursive expansion or side effects.
use super::model::*;
use serde::Serialize;
use std::collections::BTreeMap;

#[derive(Default)]
pub struct Context {
    pub dates: BTreeMap<String, String>,
}
impl Context {
    pub fn now() -> Self {
        let now = chrono::Local::now();
        Self {
            dates: [
                ("date", "%Y-%m-%d"),
                ("date:iso", "%Y-%m-%d"),
                ("date:short", "%d/%m/%Y"),
                ("date:long", "%B %-d, %Y"),
                ("time", "%H:%M"),
                ("time:12h", "%-I:%M %p"),
            ]
            .into_iter()
            .map(|(key, format)| (key.into(), now.format(format).to_string()))
            .collect(),
        }
    }
}
#[derive(Debug, Serialize)]
pub struct Evaluation {
    pub text: Option<String>,
    pub missing: Vec<String>,
}
#[derive(Debug)]
enum Part<'a> {
    Text(&'a str),
    Field(&'a str),
}
fn parse(template: &str) -> Result<Vec<Part<'_>>, String> {
    let mut parts = vec![];
    let mut rest = template;
    while let Some(start) = rest.find("{{") {
        parts.push(Part::Text(&rest[..start]));
        rest = &rest[start + 2..];
        let end = rest.find("}}").ok_or("Close each dynamic field with }}.")?;
        parts.push(Part::Field(rest[..end].trim()));
        rest = &rest[end + 2..];
    }
    parts.push(Part::Text(rest));
    Ok(parts)
}
fn field_parts(field: &str) -> (&str, Vec<&str>) {
    let mut pieces = field.split('|').map(str::trim);
    (pieces.next().unwrap_or_default(), pieces.collect())
}
pub fn validate_template(d: &Definition, c: &Configuration) -> Result<(), String> {
    for part in parse(&d.template)? {
        if let Part::Field(field) = part {
            let (source, transforms) = field_parts(field);
            let known = [
                "date",
                "date:iso",
                "date:short",
                "date:long",
                "time",
                "time:12h",
            ]
            .contains(&source)
                || source
                    .strip_prefix("input:")
                    .is_some_and(|key| d.inputs.iter().any(|i| i.key == key))
                || source
                    .strip_prefix("lookup:")
                    .is_some_and(|key| d.inputs.iter().any(|i| i.key == key && i.kind == "choice"))
                || source
                    .strip_prefix("value:")
                    .is_some_and(|key| c.values.contains_key(key));
            if !known {
                return Err(format!("Unknown field: {source}. Use Insert Field or add the matching input/saved value."));
            }
            for operation in transforms {
                if !["trim", "upper", "lower"].contains(&operation)
                    && !operation.starts_with("default:")
                {
                    return Err(format!("Unsupported formatting operation: {operation}"));
                }
            }
        }
    }
    Ok(())
}
pub fn evaluate(
    record: &Record,
    supplied: &BTreeMap<String, String>,
    context: &Context,
) -> Result<Evaluation, String> {
    record.validate()?;
    let mut arguments = record.configuration.defaults.clone();
    arguments.extend(supplied.clone());
    let mut missing = vec![];
    for input in &record.definition.inputs {
        let value = arguments.get(&input.key).map(String::as_str).unwrap_or("");
        if value.len() > 65536 {
            return Err("An input is too long.".into());
        }
        if value.trim().is_empty() {
            if input.required {
                missing.push(input.key.clone());
            }
            continue;
        }
        if input.kind == "number" && !value.parse::<f64>().is_ok_and(f64::is_finite) {
            return Err(format!("{} must be a number.", input.label));
        }
        if input.kind == "choice"
            && !record.configuration.choices[&input.key]
                .iter()
                .any(|c| c.key == value)
        {
            return Err(format!("Choose a valid {}.", input.label));
        }
    }
    if !missing.is_empty() {
        return Ok(Evaluation {
            text: None,
            missing,
        });
    }
    let mut text = String::new();
    for part in parse(&record.definition.template)? {
        match part {
            Part::Text(value) => text.push_str(value),
            Part::Field(field) => {
                let (source, transforms) = field_parts(field);
                let mut value = if let Some(key) = source.strip_prefix("input:") {
                    arguments.get(key).cloned().unwrap_or_default()
                } else if let Some(key) = source.strip_prefix("lookup:") {
                    record.configuration.choices[key]
                        .iter()
                        .find(|row| Some(&row.key) == arguments.get(key))
                        .map(|row| row.value.clone())
                        .unwrap_or_default()
                } else if let Some(key) = source.strip_prefix("value:") {
                    record.configuration.values[key].clone()
                } else {
                    context
                        .dates
                        .get(source)
                        .cloned()
                        .ok_or_else(|| format!("Could not resolve {source}"))?
                };
                for operation in transforms {
                    value = match operation {
                        "trim" => value.trim().into(),
                        "upper" => value.to_uppercase(),
                        "lower" => value.to_lowercase(),
                        fallback if fallback.starts_with("default:") && value.is_empty() => {
                            fallback[8..].into()
                        }
                        _ => value,
                    };
                }
                text.push_str(&value);
            }
        }
        if text.len() > 131072 {
            return Err("The result exceeds 128 KB.".into());
        }
    }
    Ok(Evaluation {
        text: Some(text),
        missing,
    })
}
