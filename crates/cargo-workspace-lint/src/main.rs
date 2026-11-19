#![forbid(unsafe_code)]

use anyhow::{anyhow, bail, Context, Result};
use camino::Utf8PathBuf;
use serde::Deserialize;
use std::{fs, path::Path};
use walkdir::WalkDir;

const REQUIRED_EDITION: &str = "2024";
const REQUIRED_RUST_VERSION: &str = "1.85";
const REQUIRED_LICENSE: &str = "MIT OR Apache-2.0";

const REQUIRED_HOST_DID: &str = "did:vital:bostrom";
const REQUIRED_BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
const REQUIRED_ALN_CLAUSE: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

const FORBIDDEN_FEATURES: &[&str] = &[
    "dreamplex",
    "dreamcontext",
    "subconscious_targeting",
    "anonymous_neural_scoring",
];

fn main() -> Result<()> {
    let root = Utf8PathBuf::from(".");
    let workspace_toml = root.join("Cargo.toml");

    let workspace = load_workspace_manifest(&workspace_toml)
        .with_context(|| format!("failed to parse workspace manifest at {}", workspace_toml))?;

    lint_workspace_package(&workspace)?;
    lint_workspace_members(&root, &workspace)?;
    lint_global_manifest_invariants(&root)?;

    println!("cargo-workspace-lint: all checks passed.");
    Ok(())
}

#[derive(Debug)]
struct PackageMeta {
    edition: Option<String>,
    rust_version: Option<String>,
    license: Option<String>,
}

fn parse_manifest_meta(path: &Path) -> Result<Option<PackageMeta>> {
    let text = fs::read_to_string(path)
        .with_context(|| format!("reading manifest {}", path.display()))?;
    let value: toml::Value =
        toml::from_str(&text).with_context(|| format!("parsing TOML {}", path.display()))?;

    if !value.get("package").is_some() && !value.get("workspace").is_some() {
        return Ok(None);
    }

    if let Some(pkg) = value.get("package") {
        let edition = pkg
            .get("edition")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let rust_version = pkg
            .get("rust-version")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let license = pkg
            .get("license")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        Ok(Some(PackageMeta {
            edition,
            rust_version,
            license,
        }))
    } else {
        let ws_pkg = value.get("workspace").and_then(|ws| ws.get("package"));
        if let Some(ws_pkg) = ws_pkg {
            let edition = ws_pkg
                .get("edition")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            let rust_version = ws_pkg
                .get("rust-version")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            let license = ws_pkg
                .get("license")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            Ok(Some(PackageMeta {
                edition,
                rust_version,
                license,
            }))
        } else {
            Ok(None)
        }
    }
}

fn check_meta(path: &Path, meta: &PackageMeta) -> Result<()> {
    let p = path.display();
    let edition = meta
        .edition
        .as_deref()
        .ok_or_else(|| anyhow!("{p}: missing package.edition"))?;
    let rust_version = meta
        .rust_version
        .as_deref()
        .ok_or_else(|| anyhow!("{p}: missing package.rust-version"))?;
    let license = meta
        .license
        .as_deref()
        .ok_or_else(|| anyhow!("{p}: missing package.license"))?;

    if edition != REQUIRED_EDITION {
        bail!("{p}: package.edition must be \"{REQUIRED_EDITION}\", found `{edition}`");
    }
    if rust_version != REQUIRED_RUST_VERSION {
        bail!("{p}: package.rust-version must be \"{REQUIRED_RUST_VERSION}\", found `{rust_version}`");
    }
    if license != REQUIRED_LICENSE {
        bail!("{p}: package.license must be \"{REQUIRED_LICENSE}\", found `{license}`");
    }

    Ok(())
}

#[derive(Debug, Deserialize)]
struct WorkspacePackage {
    edition: Option<String>,
    #[serde(rename = "rust-version")]
    rust_version: Option<String>,
    license: Option<String>,
    publish: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct WorkspaceMetadata {
    host_did: Option<String>,
    bostrom_address: Option<String>,
    aln_clause: Option<String>,
    #[serde(rename = "no-rollback")]
    no_rollback: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct WorkspaceTable {
    package: Option<WorkspacePackage>,
    members: Option<Vec<String>>,
    metadata: Option<WorkspaceMetadata>,
}

#[derive(Debug, Deserialize)]
struct RootManifest {
    workspace: Option<WorkspaceTable>,
}

fn load_workspace_manifest(path: &Utf8PathBuf) -> Result<RootManifest> {
    let bytes = fs::read(path)?;
    let s = String::from_utf8(bytes)?;
    let manifest: RootManifest = toml::from_str(&s)?;
    Ok(manifest)
}

fn lint_workspace_package(root: &RootManifest) -> Result<()> {
    let ws = root
        .workspace
        .as_ref()
        .ok_or_else(|| anyhow!("workspace.table missing in root Cargo.toml"))?;

    let pkg = ws
        .package
        .as_ref()
        .ok_or_else(|| anyhow!("[workspace.package] missing in root Cargo.toml"))?;

    if pkg.edition.as_deref() != Some(REQUIRED_EDITION) {
        return Err(anyhow!(
            "workspace edition must be \"{}\"",
            REQUIRED_EDITION
        ));
    }
    if pkg.rust_version.as_deref() != Some(REQUIRED_RUST_VERSION) {
        return Err(anyhow!(
            "workspace rust-version must be \"{}\"",
            REQUIRED_RUST_VERSION
        ));
    }
    if pkg.license.as_deref() != Some(REQUIRED_LICENSE) {
        return Err(anyhow!(
            "workspace license must be \"{}\"",
            REQUIRED_LICENSE
        ));
    }
    if pkg.publish != Some(false) {
        return Err(anyhow!(
            "workspace publish must be false to keep crates host-local"
        ));
    }

    let meta = ws
        .metadata
        .as_ref()
        .ok_or_else(|| anyhow!("[workspace.metadata] missing in root Cargo.toml"))?;

    if meta.host_did.as_deref() != Some(REQUIRED_HOST_DID) {
        return Err(anyhow!(
            "workspace.metadata.host_did must be \"{}\"",
            REQUIRED_HOST_DID
        ));
    }
    if meta
        .bostrom_address
        .as_deref()
        != Some(REQUIRED_BOSTROM_ADDRESS)
    {
        return Err(anyhow!(
            "workspace.metadata.bostrom_address must be sovereign Bostrom address {}",
            REQUIRED_BOSTROM_ADDRESS
        ));
    }
    if meta.aln_clause.as_deref() != Some(REQUIRED_ALN_CLAUSE) {
        return Err(anyhow!(
            "workspace.metadata.aln_clause must assert {}",
            REQUIRED_ALN_CLAUSE
        ));
    }
    if meta.no_rollback != Some(true) {
        return Err(anyhow!(
            "workspace.metadata.no-rollback must be true to enforce neurorights continuity"
        ));
    }

    Ok(())
}

#[derive(Debug, Deserialize)]
struct PackageMetadata {
    #[serde(rename = "cybercore")]
    cybercore: Option<CybercoreMetadata>,
}

#[derive(Debug, Deserialize)]
struct CybercoreMetadata {
    host_did: Option<String>,
    bostrom_address: Option<String>,
    migrationclause: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PackageTable {
    name: String,
    edition: Option<String>,
    #[serde(rename = "rust-version")]
    rust_version: Option<String>,
    license: Option<String>,
    publish: Option<bool>,
    #[serde(rename = "metadata")]
    metadata: Option<PackageMetadata>,
}

#[derive(Debug, Deserialize)]
struct CrateManifest {
    package: PackageTable,
    #[serde(default)]
    dependencies: toml::Table,
    #[serde(rename = "dev-dependencies")]
    #[serde(default)]
    dev_dependencies: toml::Table,
    #[serde(default)]
    features: toml::Table,
}

fn lint_workspace_members(root: &Utf8PathBuf, workspace: &RootManifest) -> Result<()> {
    let ws = workspace
        .workspace
        .as_ref()
        .ok_or_else(|| anyhow!("workspace.table missing"))?;
    let members = ws
        .members
        .as_ref()
        .ok_or_else(|| anyhow!("workspace.members missing"))?;

    for member in members {
        let manifest_path = root.join(member).join("Cargo.toml");
        if !manifest_path.exists() {
            return Err(anyhow!(
                "manifest missing for workspace member {} at {}",
                member,
                manifest_path
            ));
        }

        let crate_manifest = load_crate_manifest(&manifest_path)
            .with_context(|| format!("failed to parse {}", manifest_path))?;

        lint_crate_manifest(&crate_manifest, &manifest_path)?;
    }

    lint_forbidden_features_in_tree(root)?;
    Ok(())
}

fn load_crate_manifest(path: &Utf8PathBuf) -> Result<CrateManifest> {
    let bytes = fs::read(path)?;
    let s = String::from_utf8(bytes)?;
    let manifest: CrateManifest = toml::from_str(&s)?;
    Ok(manifest)
}

fn lint_crate_manifest(manifest: &CrateManifest, path: &Utf8PathBuf) -> Result<()> {
    let pkg = &manifest.package;

    if pkg.edition.as_deref() != Some(REQUIRED_EDITION) {
        return Err(anyhow!(
            "crate {} at {} must use edition = \"{}\"",
            pkg.name,
            path,
            REQUIRED_EDITION
        ));
    }
    if pkg.rust_version.as_deref() != Some(REQUIRED_RUST_VERSION) {
        return Err(anyhow!(
            "crate {} at {} must use rust-version = \"{}\"",
            pkg.name,
            path,
            REQUIRED_RUST_VERSION
        ));
    }
    if pkg.license.as_deref() != Some(REQUIRED_LICENSE) {
        return Err(anyhow!(
            "crate {} at {} must use license = \"{}\"",
            pkg.name,
            path,
            REQUIRED_LICENSE
        ));
    }
    if pkg.publish != Some(false) {
        return Err(anyhow!(
            "crate {} at {} must set publish = false",
            pkg.name,
            path
        ));
    }

    ensure_kani_present(&manifest.dev_dependencies, &pkg.name, path)?;
    ensure_cybercore_binding(pkg, path)?;

    Ok(())
}

fn ensure_kani_present(
    dev_deps: &toml::Table,
    crate_name: &str,
    path: &Utf8PathBuf,
) -> Result<()> {
    if !dev_deps.contains_key("kani-verifier") && !dev_deps.contains_key("kani") {
        return Err(anyhow!(
            "crate {} at {} must include Kani (kani-verifier or kani) in [dev-dependencies]",
            crate_name,
            path
        ));
    }
    Ok(())
}

fn ensure_cybercore_binding(pkg: &PackageTable, path: &Utf8PathBuf) -> Result<()> {
    if let Some(meta) = &pkg.metadata {
        if let Some(cybercore) = &meta.cybercore {
            if cybercore.host_did.as_deref() != Some(REQUIRED_HOST_DID) {
                return Err(anyhow!(
                    "crate {} at {} has package.metadata.cybercore.host_did != {}",
                    pkg.name,
                    path,
                    REQUIRED_HOST_DID
                ));
            }
            if cybercore
                .bostrom_address
                .as_deref()
                != Some(REQUIRED_BOSTROM_ADDRESS)
            {
                return Err(anyhow!(
                    "crate {} at {} has package.metadata.cybercore.bostrom_address != {}",
                    pkg.name,
                    path,
                    REQUIRED_BOSTROM_ADDRESS
                ));
            }
            if cybercore
                .migrationclause
                .as_deref()
                != Some(REQUIRED_ALN_CLAUSE)
            {
                return Err(anyhow!(
                    "crate {} at {} must assert {} in package.metadata.cybercore.migrationclause",
                    pkg.name,
                    path,
                    REQUIRED_ALN_CLAUSE
                ));
            }
        }
    }

    Ok(())
}

fn lint_forbidden_features_in_tree(root: &Utf8PathBuf) -> Result<()> {
    for entry in WalkDir::new(root).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }
        if entry.file_name() != "Cargo.toml" {
            continue;
        }

        let path = Utf8PathBuf::from_path_buf(entry.into_path())
            .map_err(|_| anyhow!("non-UTF8 path in workspace"))?;
        let contents = fs::read_to_string(&path)?;

        for forbidden in FORBIDDEN_FEATURES {
            if contents.contains(forbidden) {
                return Err(anyhow!(
                    "forbidden feature \"{}\" referenced in {}",
                    forbidden,
                    path
                ));
            }
        }
    }
    Ok(())
}

fn lint_global_manifest_invariants(root: &Utf8PathBuf) -> Result<()> {
    let root_fs = Path::new(root.as_str());
    for entry in WalkDir::new(root_fs)
        .into_iter()
        .filter_entry(|e| !e.path().to_string_lossy().contains("/target/"))
    {
        let entry = entry?;
        let path = entry.path();
        if !path.ends_with("Cargo.toml") {
            continue;
        }

        if let Some(meta) = parse_manifest_meta(path)? {
            check_meta(path, &meta)?;
        }
    }

    Ok(())
}
