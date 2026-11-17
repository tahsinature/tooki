use super::storage::*;
use serde_json::json;
fn document(text: &str) -> serde_json::Value {
    json!({"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":text}]}]})
}
#[test]
fn persists_documents_and_searches_content_without_losing_formatting() {
    let path =
        std::env::temp_dir().join(format!("tooki-notes-test-{}.sqlite3", std::process::id()));
    let db = Storage::open(&path).unwrap();
    let note = db
        .create("Example", document("Searchable thought 📝"))
        .unwrap();
    drop(db);
    let db = Storage::open(&path).unwrap();
    assert_eq!(
        db.get(&note.id).unwrap().document,
        document("Searchable thought 📝")
    );
    assert_eq!(db.search("thought", false).unwrap()[0].id, note.id);
    assert_eq!(db.search("📝", false).unwrap().len(), 1);
    drop(db);
    std::fs::remove_file(path).unwrap();
}
#[test]
fn stale_autosaves_cannot_overwrite_newer_text_or_restore_deleted_notes() {
    let db = Storage::open(std::path::Path::new(":memory:")).unwrap();
    let note = db.create("", empty_document()).unwrap();
    let saved = db.save(&note.id, 0, "Latest", document("keep me")).unwrap();
    assert!(db
        .save(&note.id, 0, "Older", document("discard me"))
        .is_err());
    db.flag(&note.id, "deleted", true).unwrap();
    assert!(db
        .save(&note.id, saved.revision, "Late save", empty_document())
        .is_err());
    assert!(db.search("", false).unwrap().is_empty());
    assert_eq!(db.search("keep me", true).unwrap().len(), 1);
    db.flag(&note.id, "deleted", false).unwrap();
    assert_eq!(db.get(&note.id).unwrap().text, "keep me");
}
#[test]
fn literal_queries_pin_order_and_invalid_documents() {
    let db = Storage::open(std::path::Path::new(":memory:")).unwrap();
    let a = db
        .create("100% saved", document("literal \"quote\""))
        .unwrap();
    db.create("Other", empty_document()).unwrap();
    db.flag(&a.id, "pinned", true).unwrap();
    assert_eq!(db.search("", false).unwrap()[0].id, a.id);
    assert_eq!(db.search("%", false).unwrap().len(), 1);
    assert_eq!(db.search("\"quote\"", false).unwrap().len(), 1);
    assert!(db.create("bad", json!({"type":"html"})).is_err());
}
#[test]
fn links_only_open_note_ids() {
    assert!(super::parse_link(
        &tauri::Url::parse("tooki://notes/0123456789abcdef0123456789abcdef").unwrap()
    )
    .is_ok());
    assert!(super::parse_link(
        &tauri::Url::parse("tooki-preview://notes/0123456789abcdef0123456789abcdef").unwrap()
    )
    .is_ok());
    for link in [
        "tooki-preview://notes/delete",
        "tooki-preview://notes/0123456789abcdef0123456789abcdef?delete=true",
        "tooki-preview://user@notes/0123456789abcdef0123456789abcdef",
    ] {
        assert!(super::parse_link(&tauri::Url::parse(link).unwrap()).is_err());
    }
}

#[test]
fn search_matches_display_titles_partial_text_and_excludes_trash() {
    let db = Storage::open(std::path::Path::new(":memory:")).unwrap();
    let empty = db.create("", empty_document()).unwrap();
    let named = db
        .create("Meeting notes", document("Discuss quarterly roadmap"))
        .unwrap();
    let inferred = db.create("", document("Project review")).unwrap();
    assert_eq!(db.search("until", false).unwrap()[0].id, empty.id);
    assert_eq!(db.search("UNTITLED", false).unwrap()[0].id, empty.id);
    assert_eq!(db.search("mtng", false).unwrap()[0].id, named.id);
    assert_eq!(db.search("quarter", false).unwrap()[0].id, named.id);
    assert_eq!(db.search("prjrev", false).unwrap()[0].id, inferred.id);
    assert!(db.search("nothingmatches", false).unwrap().is_empty());
    db.flag(&empty.id, "deleted", true).unwrap();
    assert!(db.search("until", false).unwrap().is_empty());
    assert_eq!(db.search("until", true).unwrap()[0].id, empty.id);
}
