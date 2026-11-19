#![forbid(unsafe_code)]

use anyhow::{anyhow, Context, Result};
use camino::Utf8PathBuf;
use cargo_metadata::{Metadata, MetadataCommand, Node, PackageId};
use serde::Deserialize;
use std::{collections::HashMap, fs, path::PathBuf};
use thiserror::Error;
use walkdir::WalkDir;

const NANOROBOTICS_PREFIX: &str = "nanorobotics-";
const NANOSWARM_PREFIX: &str = "nanoswarm-";

const FORBIDDEN_DEP_NAMES: &[&str] = &[
    "blake",
    "blake3",
    "blake2",
    "sha3",
    "sha256",
    "sha-256",
    "keccak",
    "keccak-256",
    "ripemd160",
    "xxhash",
];

#[derive(Debug, Error)]
enum DomainError {
    #[error("crate `{0}` missing [package.metadata.cybercore]")]
    MissingMetadata(String),
    #[error("crate `{0}`: ui/tooling crate must not have can_touch_actuation = true")]
    UiActuation(String),
    #[error("crate `{ui}`: ui/tooling crate depends on core_guard crate `{guard}`")]
    UiDependsOnGuard { ui: String, guard: String },
    #[error("crate `{guard}`: core_guard crate depends on forbidden domain crate `{dep}` (domain={domain})")]
    GuardDependsOnForbidden {
        guard: String,
        dep: String,
        domain: String,
    },
    #[error("governance crate `{gov}` must not be depended on by physio crate `{physio}`")]
    PhysioDependsOnGovernance { physio: String, gov: String },
}

#[derive(Debug, Deserialize, Clone)]
struct CybercoreMeta {
    domain: String,
    roh_role: String,
    can_touch_actuation: bool,
}

#[derive(Debug, Clone)]
struct CrateInfo {
    name: String,
    meta: CybercoreMeta,
}

#[derive(Debug, Deserialize)]
struct WorkspaceTableSimple {
    members: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
struct WorkspaceManifest {
    workspace: Option<WorkspaceTableSimple>,
}

#[derive(Debug, Deserialize)]
struct Package {
    name: String,
}

#[derive(Debug, Deserialize)]
struct CrateManifest {
    package: Package,
    #[serde(default)]
    dependencies: toml::Table,
    #[serde(rename = "dev-dependencies")]
    #[serde(default)]
    dev_dependencies: toml::Table,
}

fn main() -> Result<()> {
    let root_utf8 = Utf8PathBuf::from(".");
    let workspace_toml = root_utf8.join("Cargo.toml");

    let workspace = load_workspace_manifest(&workspace_toml)
        .with_context(|| format!("Failed to parse workspace manifest at {}", workspace_toml))?;

    let members = workspace
        .workspace
        .and_then(|w| w.members)
        .ok_or_else(|| anyhow!("workspace.members missing in root Cargo.toml"))?;

    for member in &members {
        let manifest_path = root_utf8.join(member).join("Cargo.toml");
        if !manifest_path.exists() {
            return Err(anyhow!(
                "crate manifest missing for member {} at {}",
                member,
                manifest_path
            ));
        }

        let crate_manifest = load_crate_manifest(&manifest_path)
            .with_context(|| format!("Failed to parse {}", manifest_path))?;

        lint_domain_for_crate(&root_utf8, &manifest_path, &crate_manifest)?;
    }

    // Cargo graph / cybercore-domain policies
    let root_std = PathBuf::from(".");
    let meta = load_metadata(&root_std)?;
    let crate_info = build_crate_info(&root_std, &meta)?;

    let resolve = meta
        .resolve
        .as_ref()
        .ok_or_else(|| anyhow!("metadata.resolve missing from cargo metadata"))?;
    let mut node_map: HashMap<&PackageId, &Node> = HashMap::new();
    for node in &resolve.nodes {
        node_map.insert(&node.id, node);
    }

    for (_id, info) in &crate_info {
        if matches!(info.meta.domain.as_str(), "ui" | "tooling") && info.meta.can_touch_actuation {
            return Err(DomainError::UiActuation(info.name.clone()).into());
        }
    }

    for (id, info) in &crate_info {
        let node = match node_map.get(id) {
            Some(n) => *n,
            None => continue,
        };

        for dep in &node.deps {
            let dep_info = match crate_info.get(&dep.pkg) {
                Some(ci) => ci,
                None => continue,
            };

            if matches!(info.meta.domain.as_str(), "ui" | "tooling")
                && dep_info.meta.roh_role == "core_guard"
            {
                return Err(DomainError::UiDependsOnGuard {
                    ui: info.name.clone(),
                    guard: dep_info.name.clone(),
                }
                .into());
            }

            if info.meta.roh_role == "core_guard" {
                let d = dep_info.meta.domain.as_str();
                let allowed = matches!(
                    d,
                    "pqc" | "telemetry" | "core_math" | "aln_loader" | "physio"
                );
                if !allowed {
                    return Err(DomainError::GuardDependsOnForbidden {
                        guard: info.name.clone(),
                        dep: dep_info.name.clone(),
                        domain: dep_info.meta.domain.clone(),
                    }
                    .into());
                }
            }

            if info.meta.domain == "physio" && dep_info.meta.domain == "governance" {
                return Err(DomainError::PhysioDependsOnGovernance {
                    physio: info.name.clone(),
                    gov: dep_info.name.clone(),
                }
                .into());
            }
        }
    }

    println!("cargo-domain-lint: all domain, RoH, actuation, and manifest checks passed.");
    Ok(())
}

fn load_metadata(root: &PathBuf) -> Result<Metadata> {
    let mut cmd = MetadataCommand::new();
    cmd.current_dir(root);
    let meta = cmd.exec().context("running cargo metadata")?;
    Ok(meta)
}

fn load_cybercore_meta(root: &PathBuf, manifest_path: &PathBuf) -> Result<Option<CybercoreMeta>> {
    let full = root.join(manifest_path);
    let text = fs::read_to_string(&full)
        .with_context(|| format!("reading manifest {}", full.display()))?;
    let value: toml::Value =
        toml::from_str(&text).with_context(|| format!("parsing TOML {}", full.display()))?;

    let meta = value
        .get("package")
        .and_then(|p| p.get("metadata"))
        .and_then(|m| m.get("cybercore"));
    if let Some(m) = meta {
        let domain = m
            .get("domain")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let roh_role = m
            .get("roh_role")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let can_touch_actuation = m
            .get("can_touch_actuation")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        Ok(Some(CybercoreMeta {
            domain,
            roh_role,
            can_touch_actuation,
        }))
    } else {
        Ok(None)
    }
}

fn build_crate_info(root: &PathBuf, meta: &Metadata) -> Result<HashMap<PackageId, CrateInfo>> {
    let mut map = HashMap::new();
    for pkg in &meta.packages {
        if let Some(ref manifest_path) = pkg.manifest_path {
            let manifest_rel = PathBuf::from(manifest_path.as_str());
            let cmeta = load_cybercore_meta(root, &manifest_rel)?;
            let cmeta = cmeta.ok_or_else(|| DomainError::MissingMetadata(pkg.name.clone()))?;
            map.insert(
                pkg.id.clone(),
                CrateInfo {
                    name: pkg.name.clone(),
                    meta: cmeta,
                },
            );
        }
    }
    Ok(map)
}

fn load_workspace_manifest(path: &Utf8PathBuf) -> Result<WorkspaceManifest> {
    let bytes = fs::read(path)?;
    let s = String::from_utf8(bytes)?;
    let manifest: WorkspaceManifest = toml::from_str(&s)?;
    Ok(manifest)
}

fn load_crate_manifest(path: &Utf8PathBuf) -> Result<CrateManifest> {
    let bytes = fs::read(path)?;
    let s = String::from_utf8(bytes)?;
    let manifest: CrateManifest = toml::from_str(&s)?;
    Ok(manifest)
}

fn lint_domain_for_crate(
    root: &Utf8PathBuf,
    manifest_path: &Utf8PathBuf,
    manifest: &CrateManifest,
) -> Result<()> {
    let name = &manifest.package.name;

    if name.starts_with(NANOROBOTICS_PREFIX) || name.starts_with(NANOSWARM_PREFIX) {
        ensure_core_deps_present(manifest, manifest_path)?;
        ensure_forbidden_deps_absent(manifest, manifest_path)?;
        ensure_kani_if_harness_present(root, manifest_path, manifest)?;
    } else {
        ensure_forbidden_deps_absent(manifest, manifest_path)?;
    }

    Ok(())
}

fn ensure_core_deps_present(manifest: &CrateManifest, manifest_path: &Utf8PathBuf) -> Result<()> {
    if !manifest.dependencies.contains_key("serde") {
        return Err(anyhow!(
            "crate {} at {} must depend on workspace serde for telemetry and ALN wiring",
            manifest.package.name,
            manifest_path
        ));
    }
    if !manifest.dependencies.contains_key("anyhow") {
        return Err(anyhow!(
            "crate {} at {} must depend on workspace anyhow for error semantics",
            manifest.package.name,
            manifest_path
        ));
    }
    Ok(())
}

fn ensure_forbidden_deps_absent(
    manifest: &CrateManifest,
    manifest_path: &Utf8PathBuf,
) -> Result<()> {
    let mut check_table = |table: &toml::Table, section: &str| -> Result<()> {
        for (name, _) in table.iter() {
            let lname = name.to_ascii_lowercase();
            for forbidden in FORBIDDEN_DEP_NAMES {
                if lname.contains(forbidden) {
                    return Err(anyhow!(
                        "crate {} at {} uses forbidden dependency \"{}\" in [{}]",
                        manifest.package.name,
                        manifest_path,
                        name,
                        section
                    ));
                }
            }
        }
        Ok(())
    };

    check_table(&manifest.dependencies, "dependencies")?;
    check_table(&manifest.dev_dependencies, "dev-dependencies")?;
    Ok(())
}

fn ensure_kani_if_harness_present(
    root: &Utf8PathBuf,
    manifest_path: &Utf8PathBuf,
    manifest: &CrateManifest,
) -> Result<()> {
    let crate_dir = manifest_path
        .parent()
        .ok_or_else(|| anyhow!("manifest path {} has no parent directory", manifest_path))?;

    let mut has_kani_source = false;

    for entry in WalkDir::new(crate_dir).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }
        let file_name = entry.file_name().to_string_lossy();
        if file_name.ends_with("kani.rs") || file_name.contains("kani_harness") {
            has_kani_source = true;
            break;
        }
    }

    if has_kani_source {
        if !(manifest.dev_dependencies.contains_key("kani-verifier")
            || manifest.dev_dependencies.contains_key("kani"))
        {
            return Err(anyhow!(
                "crate {} at {} contains Kani harness source files but no kani/kani-verifier dev-dependency",
                manifest.package.name,
                manifest_path
            ));
        }
    }

    if has_kani_source {
        let _workspace_root = root;
    }

    Ok(())
}
