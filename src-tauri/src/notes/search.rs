//! Match the same displayed title used by the note browser, plus literal body text.
pub fn matches(title: &str, text: &str, query: &str) -> bool {
    let query = query.trim().to_lowercase();
    if query.is_empty() || text.to_lowercase().contains(&query) {
        return true;
    }
    let displayed = if title.is_empty() {
        text.lines()
            .find(|line| !line.trim().is_empty())
            .map(|line| line.chars().take(80).collect::<String>())
            .unwrap_or_else(|| "Untitled note".into())
    } else {
        title.to_owned()
    };
    let mut remaining = query.chars().peekable();
    for character in displayed.to_lowercase().chars() {
        if remaining.peek() == Some(&character) {
            remaining.next();
        }
    }
    remaining.next().is_none()
}
