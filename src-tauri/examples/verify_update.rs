//! Release preflight: prove the published package matches the key embedded in the app.
use base64::{engine::general_purpose::STANDARD, Engine};
use minisign_verify::{PublicKey, Signature};
use std::{error::Error, fs, path::Path};

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 3 {
        return Err("Usage: verify_update VERSION ARTIFACT_DIRECTORY".into());
    }
    let directory = Path::new(&args[2]);
    let config: serde_json::Value = serde_json::from_str(include_str!("../tauri.conf.json"))?;
    let public_key = config["plugins"]["updater"]["pubkey"]
        .as_str()
        .ok_or("Missing public key")?;
    let public_key = PublicKey::decode(&String::from_utf8(STANDARD.decode(public_key)?)?)?;
    let signature_text = fs::read_to_string(directory.join("Tooki.app.tar.gz.sig"))?;
    let signature =
        Signature::decode(&String::from_utf8(STANDARD.decode(signature_text.trim())?)?)?;
    let archive = fs::read(directory.join("Tooki.app.tar.gz"))?;
    public_key.verify(&archive, &signature, true)?;
    let signed_version = signature
        .trusted_comment()
        .split('\t')
        .find_map(|part| part.strip_prefix("version:"));
    if signed_version != Some(args[1].as_str()) {
        return Err("The signature is not bound to the release version".into());
    }
    let manifest: serde_json::Value =
        serde_json::from_slice(&fs::read(directory.join("latest.json"))?)?;
    if manifest["version"] != args[1] {
        return Err("Manifest version mismatch".into());
    }
    let expected_url = format!(
        "https://github.com/tahsinature/tooki/releases/download/v{}/Tooki.app.tar.gz",
        args[1]
    );
    for platform in ["darwin-aarch64", "darwin-x86_64"] {
        if manifest["platforms"][platform]["url"] != expected_url {
            return Err("Manifest download URL mismatch".into());
        }
        if manifest["platforms"][platform]["signature"] != signature_text.trim() {
            return Err("Manifest signature mismatch".into());
        }
    }
    println!(
        "Verified update signature and version {} against the embedded public key.",
        args[1]
    );
    Ok(())
}
