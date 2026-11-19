//! Same data contract as the theme editor. Reject before replacing loaded themes.
use serde_json::Value;
use std::sync::OnceLock;
fn contract() -> &'static Value {
    static CONTRACT: OnceLock<Value> = OnceLock::new();
    CONTRACT.get_or_init(|| {
        serde_json::from_str(include_str!("../../../src/lib/themes/contract.json"))
            .expect("Bundled theme contract")
    })
}
fn color(value: &Value) -> bool {
    value.as_str().is_some_and(|s| {
        s.len() == 7 && s.starts_with('#') && s.as_bytes()[1..].iter().all(u8::is_ascii_hexdigit)
    })
}
fn bounded(value: &Value, min: f64, max: f64) -> bool {
    value
        .as_f64()
        .is_some_and(|n| n.is_finite() && n >= min && n <= max)
}
pub fn validate(theme: &Value) -> Result<&str, String> {
    if theme["version"] != 1 || serde_json::to_vec(theme).map_err(|e| e.to_string())?.len() > 32_000
    {
        return Err("Expected a version 1 Tooki theme smaller than 32 KB.".into());
    }
    let id = theme["id"].as_str().ok_or("Missing theme identifier")?;
    if id.is_empty()
        || id.len() > 64
        || !id.as_bytes()[0].is_ascii_lowercase()
        || !id
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
    {
        return Err("Use a short lowercase theme identifier.".into());
    }
    for key in ["name", "author"] {
        if !theme[key]
            .as_str()
            .is_some_and(|v| !v.trim().is_empty() && v.encode_utf16().count() <= 80)
        {
            return Err(format!("Theme {key} must be 1–80 characters."));
        }
    }
    if !matches!(theme["appearance"].as_str(), Some("light" | "dark")) {
        return Err("Appearance must be light or dark.".into());
    }
    let tokens = theme["tokens"]
        .as_object()
        .ok_or("Theme tokens are missing")?;
    let contract = contract();
    let colors = contract["colorTokens"].as_array().unwrap();
    let dimensions = contract["dimensions"].as_object().unwrap();
    for key in tokens.keys() {
        if key != "cornerRadius"
            && !colors.iter().any(|v| v.as_str() == Some(key))
            && !dimensions.contains_key(key)
        {
            return Err(format!("Unknown theme token: {key}"));
        }
    }
    for key in colors.iter().filter_map(Value::as_str) {
        if !color(&theme["tokens"][key]) {
            return Err(format!("{key} must be a six-digit hex color."));
        }
    }
    for (key, bounds) in dimensions {
        if key == "searchFontSize" && !tokens.contains_key(key) {
            continue;
        }
        if !bounded(
            &theme["tokens"][key],
            bounds[0].as_f64().unwrap(),
            bounds[1].as_f64().unwrap(),
        ) {
            return Err(format!("Invalid theme dimension: {key}"));
        }
    }
    if let Some(radius) = tokens.get("cornerRadius") {
        if !bounded(radius, 0.0, 24.0) {
            return Err("Invalid cornerRadius".into());
        }
    }
    if let Some(components) = theme.get("components") {
        let components = components
            .as_object()
            .ok_or("Components must be an object")?;
        for (component, overrides) in components {
            let fields = contract["componentFields"][component]
                .as_array()
                .ok_or_else(|| format!("Unknown component: {component}"))?;
            let overrides = overrides
                .as_object()
                .ok_or("Component overrides must be an object")?;
            for (field, value) in overrides {
                if !fields.iter().any(|v| v.as_str() == Some(field))
                    || !(if field == "radius" {
                        bounded(value, 0.0, 24.0)
                    } else {
                        color(value)
                    })
                {
                    return Err(format!("Invalid {component}.{field}"));
                }
            }
        }
    }
    Ok(id)
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn editor_contract_rejects_incomplete_and_unsafe_themes() {
        let theme: Value =
            serde_json::from_str(include_str!("../../../src/lib/themes/graphite.json")).unwrap();
        assert!(validate(&theme).is_ok());
        let mut legacy = theme.clone();
        legacy["tokens"]
            .as_object_mut()
            .unwrap()
            .remove("searchFontSize");
        assert!(validate(&legacy).is_ok());
        for (path, value) in [
            ("/tokens/surface", json!("url(https://example.com)")),
            ("/tokens/rowHeight", json!(1)),
            ("/author", json!("")),
            ("/components", json!({"unknown":{}})),
            ("/tokens", json!({})),
        ] {
            let mut invalid = theme.clone();
            *invalid.pointer_mut(path).unwrap() = value;
            assert!(validate(&invalid).is_err(), "{path}");
        }
    }
}
