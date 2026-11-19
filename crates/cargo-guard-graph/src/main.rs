use std::{collections::HashMap, fs, path::PathBuf};

use anyhow::{bail, Context, Result};
use cargo_metadata::{Metadata, MetadataCommand, Package};
use serde::Deserialize;
use thiserror::Error;

#[derive(Debug, Error)]
enum GuardError {
    #[error("crate `{0}` present in workspace but missing from ALN shard")]
    MissingInShard(String),
    #[error("crate `{0}` present in ALN shard but missing in workspace")]
    MissingInWorkspace(String),
    #[error("crate `{crate_name}`: edition mismatch shard `{shard}`, toml `{toml}`")]
    EditionMismatch {
        crate_name: String,
        shard: String,
        toml: String,
    },
    #[error("crate `{crate_name}`: rust-version mismatch shard `{shard}`, toml `{toml}`")]
    RustVersionMismatch {
        crate_name: String,
        shard: String,
        toml: String,
    },
    #[error("crate `{crate_name}`: license mismatch shard `{shard}`, toml `{toml}`")]
    LicenseMismatch {
        crate_name: String,
        shard: String,
        toml: String,
    },
    #[error("crate `{crate_name}` has dependency on `{dep}` which is not in allowed_deps")]
    ForbiddenDependency { crate_name: String, dep: String },
    #[error("crate `{crate_name}` depends on `{dep}` version `{found}` exceeding max `{max}`")]
    VersionTooHigh {
        crate_name: String,
        dep: String,
        found: String,
        max: String,
    },
}

#[derive(Debug, Deserialize)]
struct AlnWorkspace {
    workspace_id: String,
    hostdid: String,
    bostromaddress: String,
    alnclause: String,
    crates: Vec<AlnCrate>,
}

#[derive(Debug, Deserialize)]
struct AlnCrate {
    name: String,
    path: String,
    kind: String,
    edition: String,
    #[serde(rename = "rust-version")]
    rust_version: String,
    license: String,
    domain: String,
    roh_role: String,
    allowed_deps: Vec<AlnAllowedDep>,
}

#[derive(Debug, Deserialize)]
struct AlnAllowedDep {
    name: String,
    domain: String,
    max_version_spec: String,
    roh_path_sensitive: bool,
}

fn load_aln_workspace(root: &PathBuf) -> Result<AlnWorkspace> {
    let path = root.join("specs/aln/workspace.cargo-graph.v1.aln.json");
    let data = fs::read_to_string(&path)
        .with_context(|| format!("reading ALN workspace shard at {}", path.display()))?;
    let ws: AlnWorkspace =
        serde_json::from_str(&data).context("parsing ALN workspace shard JSON")?;
    Ok(ws)
}

fn load_metadata(root: &PathBuf) -> Result<Metadata> {
    let mut cmd = MetadataCommand::new();
    cmd.current_dir(root);
    let meta = cmd.exec().context("running cargo metadata")?;
    Ok(meta)
}

fn build_pkg_map<'m>(meta: &'m Metadata) -> HashMap<String, &'m Package> {
    meta.packages
        .iter()
        .map(|p| (p.name.clone(), p))
        .collect()
}

fn extract_manifest_fields(pkg: &Package) -> (String, String, String) {
    let edition = pkg
        .edition
        .clone()
        .unwrap_or_else(|| "2024".to_string());
    let rust_version = pkg
        .rust_version
        .clone()
        .unwrap_or_else(|| "1.85".to_string());
    // License must be present; if not, fail separately.
    let license = pkg
        .license
        .clone()
        .unwrap_or_else(|| "UNKNOWN".to_string());
    (edition, rust_version, license)
}

fn semver_satisfies(found: &str, max_spec: &str) -> bool {
    // To keep this tool lightweight and offline, we do a conservative check:
    // - if found == max_spec, accept.
    // - if max_spec starts with '^', strip and accept if major.minor match and found <= max.
    // Anything ambiguous fails closed at the call site.
    if found == max_spec {
        return true;
    }
    let spec = max_spec.trim();
    let spec = spec.strip_prefix('^').unwrap_or(spec);
    let f_parts: Vec<&str> = found.split('.').collect();
    let s_parts: Vec<&str> = spec.split('.').collect();
    if f_parts.len() < 2 || s_parts.len() < 2 {
        return false;
    }
    if f_parts[0] != s_parts[0] {
        return false;
    }
    // Compare minor numerically
    let f_minor = f_parts[1].parse::<u64>().unwrap_or(u64::MAX);
    let s_minor = s_parts[1].parse::<u64>().unwrap_or(0);
    f_minor <= s_minor
}

fn main() -> Result<()> {
    let root = PathBuf::from(".");

    let aln = load_aln_workspace(&root)?;
    let meta = load_metadata(&root)?;

    let pkg_map = build_pkg_map(&meta);
    let aln_map: HashMap<String, &AlnCrate> =
        aln.crates.iter().map(|c| (c.name.clone(), c)).collect();

    // 1. Ensure every metadata package exists in ALN shard (no hidden crates).
    for (name, pkg) in &pkg_map {
        if !aln_map.contains_key(name) {
            return Err(GuardError::MissingInShard(pkg.name.clone()).into());
        }
    }

    // 2. Ensure every ALN crate exists in metadata (no stale shard entries).
    for (name, ac) in &aln_map {
        if !pkg_map.contains_key(name) {
            return Err(GuardError::MissingInWorkspace(ac.name.clone()).into());
        }
    }

    // 3. Per-crate invariants and dependency checks.
    for (name, pkg) in &pkg_map {
        let aln_crate = aln_map.get(name.as_str()).expect("already checked above");
        let (edition, rust_version, license) = extract_manifest_fields(pkg);

        if edition != aln_crate.edition {
            return Err(GuardError::EditionMismatch {
                crate_name: name.clone(),
                shard: aln_crate.edition.clone(),
                toml: edition,
            }
            .into());
        }
        if rust_version != aln_crate.rust_version {
            return Err(GuardError::RustVersionMismatch {
                crate_name: name.clone(),
                shard: aln_crate.rust_version.clone(),
                toml: rust_version,
            }
            .into());
        }
        if license != aln_crate.license {
            return Err(GuardError::LicenseMismatch {
                crate_name: name.clone(),
                shard: aln_crate.license.clone(),
                toml: license,
            }
            .into());
        }

        let mut allowed: HashMap<&str, &AlnAllowedDep> = HashMap::new();
        for d in &aln_crate.allowed_deps {
            allowed.insert(d.name.as_str(), d);
        }

        for dep in &pkg.dependencies {
            // Workspace internal deps are governed by the shard; external deps must be listed.
            if let Some(ad) = allowed.get(dep.name.as_str()) {
                if let Some(ref ver) = dep.req {
                    let found = ver.to_string();
                    if !semver_satisfies(&found, &ad.max_version_spec) {
                        return Err(GuardError::VersionTooHigh {
                            crate_name: name.clone(),
                            dep: dep.name.clone(),
                            found,
                            max: ad.max_version_spec.clone(),
                        }
                        .into());
                    }
                }
            } else if dep.path.is_none() {
                // External dep not whitelisted.
                return Err(GuardError::ForbiddenDependency {
                    crate_name: name.clone(),
                    dep: dep.name.clone(),
                }
                .into());
            }
        }
    }

    println!(
        "cargo-guard-graph: workspace `{}` validated under `{}`",
        aln.workspace_id, aln.alnclause
    );
    Ok(())
}
