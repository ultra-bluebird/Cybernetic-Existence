// SPDX-License-Identifier: MIT OR Apache-2.0

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![feature(rust_2024_preview)]

use std::env;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

use chrono::Utc;
use serde::{Deserialize, Serialize};

/// Authority constants for this host.
const HOST_DID: &str = "did:aln:organic-host";
const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
const PRIMARY_REPO: &str = "github.com/mk-bluebird/Cybercore";
const EVOLUTION_BRANCH_PREFIX: &str = "feat";
const ROD_ROH_MAX: f32 = 0.30;

/// ALN clause asserting Cybercore as authority.
const ALN_MIGRATION_CLAUSE: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Single evolution window (one daily branch).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BioscaleEvolutionWindow {
    pub valid_from: SystemTime,
    pub valid_until: SystemTime,
    pub max_upgrades_in_window: u32,
    pub max_total_energy_joules: f64,
    pub max_total_duty_fraction: f32,
    pub roh_ceiling: f32,
}

/// Aggregated state across approved upgrades in the window.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct EvolutionWindowState {
    pub approved_upgrade_ids: Vec<String>,
    pub total_energy_joules: f64,
    pub total_duty_fraction: f32,
    pub roh_max_observed: f32,
    pub daily_blood_used: f32,
    pub daily_protein_used: f32,
    pub daily_lifeforce_used: f32,
}

/// Envelope for daily vampiric healthcare budgets.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VampiricHealthcareEnvelope {
    pub blood_token_daily_max: f32,
    pub protein_token_daily_max: f32,
    pub lifeforce_daily_max: f32,
    pub pain_threshold_vas: f32,
    pub fear_threshold_score: f32,
}

/// Responsibility and RoH fields for a manifest upgrade.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ResponsibilityFields {
    pub r_before: f32,
    pub r_after: f32,
    pub roh_before: f32,
    pub roh_after: f32,
}

/// Eco responsibility and reward fields.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EcoFields {
    pub eco_delta: f32,
    pub eco_reward_tokens: f32,
    pub ceim_mass_impact: f32,
    pub karma_units: f32,
    pub eco_eligible: bool,
}

/// Vampiric usage deltas associated with an upgrade.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VampiricDeltas {
    pub blood_token_delta: f32,
    pub protein_token_delta: f32,
    pub lifeforce_token_delta: f32,
    pub pain_vas_projection: f32,
    pub fear_score_projection: f32,
}

/// Evidence bundle with exactly 10 short hex tags.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvidenceBundle10 {
    pub tags: [String; 10],
}

/// Guard verdict from nanoswarm / reality guards.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum GuardVerdict {
    Allow,
    AllowShrunk,
    Brake,
    Deny,
}

/// Nanoswarm-specific corridor IDs and guard hashes (gap you highlighted).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NanoswarmRowMeta {
    pub nanoswarm_corridor_id: Option<String>,
    pub nanoswarm_guard_hash: Option<String>,
}

/// Single manifest upgrade row for the day.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ManifestUpgradeRow {
    pub upgrade_id: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub aln_clause_ids: Vec<String>,
    pub responsibility: ResponsibilityFields,
    pub eco: EcoFields,
    pub vampiric: VampiricDeltas,
    pub evidence: EvidenceBundle10,
    pub guard_verdict: GuardVerdict,
    pub nanoswarm_meta: Option<NanoswarmRowMeta>,
}

/// Daily manifest emitted by bioscale-evolution-cli.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ResearchManifest {
    pub date_ymd: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub git_commit: String,
    pub workspace_branch: String,
    pub primary_repo: String,
    pub roh_ceiling: f32,
    pub upgrades: Vec<ManifestUpgradeRow>,
}

fn main() -> Result<(), String> {
    let phase = env::var("EVOLUTION_PHASE").unwrap_or_else(|_| "ci".to_string());
    let manifest_path = manifest_path_from_env()?;
    let manifest = load_manifest(&manifest_path)?;
    validate_identity_and_authority(&manifest)?;

    let envelope = load_daily_vampiric_envelope()?;
    let window = default_evolution_window();
    let mut state = EvolutionWindowState::default();

    // Phase-aware behavior (before-settling vs CI vs after-settling hooks)
    match phase.as_str() {
        "before-settling" => {
            // Before-settling: just persist telemetry + vampiric envelope anchor.
            persist_vampiric_aln_shard(&manifest.date_ymd, &envelope)?;
            return Ok(());
        }
        "ci" | "during-ci" => {
            // Full manifest enforcement.
        }
        "after-settling" => {
            // After-settling: nothing to re-apply here, just re-anchor invariants if desired.
        }
        _ => {
            return Err(format!("Unknown EVOLUTION_PHASE: {}", phase));
        }
    }

    for row in &manifest.upgrades {
        if !row.aln_clause_ids.iter().any(|c| c == ALN_MIGRATION_CLAUSE) {
            return Err(format!(
                "upgrade {} missing required clause {}",
                row.upgrade_id, ALN_MIGRATION_CLAUSE
            ));
        }

        // Responsibility + RoH axis.
        enforce_responsibility_and_roh(&row.responsibility, &window, &mut state)?;

        // Vampiric BLOOD / PROTEIN / LIFEFORCE / pain / fear budgets.
        enforce_vampiric_envelope(&row.vampiric, &envelope, &mut state)?;

        // Eco responsibility & rewards.
        enforce_eco_fields(&row.eco)?;

        // 10-tag evidence bundle.
        enforce_evidence_bundle(&row.evidence)?;

        // Optional nanoswarm corridor/guard binding.
        if let Some(meta) = &row.nanoswarm_meta {
            enforce_nanoswarm_binding(meta)?;
        }

        if row.guard_verdict == GuardVerdict::Allow
            || row.guard_verdict == GuardVerdict::AllowShrunk
        {
            state.approved_upgrade_ids.push(row.upgrade_id.clone());
        } else {
            // Brake / Deny rows remain for audit, not applied.
        }
    }

    if state.roh_max_observed > window.roh_ceiling + f32::EPSILON {
        return Err(format!(
            "RoH ceiling exceeded: observed={} ceiling={}",
            state.roh_max_observed, window.roh_ceiling
        ));
    }

    persist_daily_summary(&manifest, &state)?;
    Ok(())
}

fn manifest_path_from_env() -> Result<PathBuf, String> {
    let path = env::var("RESEARCH_MANIFEST_PATH")
        .map_err(|e| format!("RESEARCH_MANIFEST_PATH not set: {}", e))?;
    Ok(PathBuf::from(path))
}

fn load_manifest(path: &PathBuf) -> Result<ResearchManifest, String> {
    let data = std::fs::read(path)
        .map_err(|e| format!("failed to read manifest {}: {}", path.display(), e))?;
    serde_json::from_slice::<ResearchManifest>(&data)
        .map_err(|e| format!("failed to parse manifest {}: {}", path.display(), e))
}

fn validate_identity_and_authority(manifest: &ResearchManifest) -> Result<(), String> {
    if manifest.host_did != HOST_DID {
        return Err(format!(
            "host_did mismatch: manifest={} expected={}",
            manifest.host_did, HOST_DID
        ));
    }
    if manifest.bostrom_address != BOSTROM_ADDRESS {
        return Err(format!(
            "bostrom_address mismatch: manifest={} expected={}",
            manifest.bostrom_address, BOSTROM_ADDRESS
        ));
    }
    if manifest.primary_repo != PRIMARY_REPO {
        return Err(format!(
            "primary_repo mismatch: manifest={} expected={}",
            manifest.primary_repo, PRIMARY_REPO
        ));
    }
    if !manifest.workspace_branch.starts_with(EVOLUTION_BRANCH_PREFIX) {
        return Err(format!(
            "workspace_branch {} does not start with {}",
            manifest.workspace_branch, EVOLUTION_BRANCH_PREFIX
        ));
    }
    if (manifest.roh_ceiling - ROD_ROH_MAX).abs() > f32::EPSILON {
        return Err(format!(
            "roh_ceiling mismatch: manifest={} expected={}",
            manifest.roh_ceiling, ROD_ROH_MAX
        ));
    }
    Ok(())
}

fn load_daily_vampiric_envelope() -> Result<VampiricHealthcareEnvelope, String> {
    let path = env::var("VAMPIRIC_ENVELOPE_PATH")
        .map_err(|e| format!("VAMPIRIC_ENVELOPE_PATH not set: {}", e))?;
    let buf = PathBuf::from(path);
    let data = std::fs::read(&buf)
        .map_err(|e| format!("failed to read vampiric envelope {}: {}", buf.display(), e))?;
    serde_json::from_slice::<VampiricHealthcareEnvelope>(&data).map_err(|e| {
        format!(
            "failed to parse vampiric envelope {}: {}",
            buf.display(),
            e
        )
    })
}

fn default_evolution_window() -> BioscaleEvolutionWindow {
    let now = SystemTime::now();
    let twelve_h = Duration::from_secs(12 * 3600);
    BioscaleEvolutionWindow {
        valid_from: now,
        valid_until: now + twelve_h,
        max_upgrades_in_window: 64,
        max_total_energy_joules: 30_000.0,
        max_total_duty_fraction: 0.8,
        roh_ceiling: ROD_ROH_MAX,
    }
}

fn enforce_responsibility_and_roh(
    fields: &ResponsibilityFields,
    window: &BioscaleEvolutionWindow,
    state: &mut EvolutionWindowState,
) -> Result<(), String> {
    let r_delta = fields.r_after - fields.r_before;
    if r_delta < 0.0 {
        return Err(format!(
            "responsibility delta negative: r_before={} r_after={}",
            fields.r_before, fields.r_after
        ));
    }
    let roh_delta = fields.roh_after - fields.roh_before;
    if roh_delta > ROD_ROH_MAX + f32::EPSILON {
        return Err(format!(
            "roh_delta {} exceeds ROD_ROH_MAX {}",
            roh_delta, ROD_ROH_MAX
        ));
    }
    if fields.roh_after > window.roh_ceiling + f32::EPSILON {
        return Err(format!(
            "RoH after {} exceeds ceiling {}",
            fields.roh_after, window.roh_ceiling
        ));
    }
    if fields.roh_after > state.roh_max_observed {
        state.roh_max_observed = fields.roh_after;
    }
    Ok(())
}

fn enforce_vampiric_envelope(
    deltas: &VampiricDeltas,
    envelope: &VampiricHealthcareEnvelope,
    state: &mut EvolutionWindowState,
) -> Result<(), String> {
    let projected_blood = state.daily_blood_used + deltas.blood_token_delta;
    let projected_protein = state.daily_protein_used + deltas.protein_token_delta;
    let projected_lifeforce = state.daily_lifeforce_used + deltas.lifeforce_token_delta;

    if projected_blood > envelope.blood_token_daily_max + f32::EPSILON {
        return Err("blood_token_daily_max would be exceeded".to_string());
    }
    if projected_protein > envelope.protein_token_daily_max + f32::EPSILON {
        return Err("protein_token_daily_max would be exceeded".to_string());
    }
    if projected_lifeforce > envelope.lifeforce_daily_max + f32::EPSILON {
        return Err("lifeforce_daily_max would be exceeded".to_string());
    }
    if deltas.pain_vas_projection > envelope.pain_threshold_vas + f32::EPSILON {
        return Err("pain VAS projection exceeds daily threshold".to_string());
    }
    if deltas.fear_score_projection > envelope.fear_threshold_score + f32::EPSILON {
        return Err("fear score projection exceeds daily threshold".to_string());
    }

    state.daily_blood_used = projected_blood;
    state.daily_protein_used = projected_protein;
    state.daily_lifeforce_used = projected_lifeforce;
    Ok(())
}

fn enforce_eco_fields(eco: &EcoFields) -> Result<(), String> {
    if eco.eco_delta < 0.0 {
        return Err(format!(
            "eco_delta negative ({}), eco upgrades must be non-negative",
            eco.eco_delta
        ));
    }
    if eco.eco_eligible {
        if eco.eco_reward_tokens < 0.0 {
            return Err("eco_reward_tokens negative for eco-eligible row".to_string());
        }
        if eco.ceim_mass_impact < 0.0 {
            return Err("ceim_mass_impact negative for eco-eligible row".to_string());
        }
        if eco.karma_units < 0.0 {
            return Err("karma_units negative for eco-eligible row".to_string());
        }
    }
    Ok(())
}

fn enforce_evidence_bundle(evidence: &EvidenceBundle10) -> Result<(), String> {
    for tag in &evidence.tags {
        if tag.trim().is_empty() {
            return Err("EvidenceBundle10 contains empty tag".to_string());
        }
        if tag.len() != 8 {
            return Err(format!(
                "EvidenceBundle10 tag {} must be 8 hex chars",
                tag
            ));
        }
        if !tag.chars().all(|c| c.is_ascii_hexdigit()) {
            return Err(format!("EvidenceBundle10 tag {} is not hex", tag));
        }
    }
    Ok(())
}

fn enforce_nanoswarm_binding(meta: &NanoswarmRowMeta) -> Result<(), String> {
    if meta.nanoswarm_corridor_id.is_none() && meta.nanoswarm_guard_hash.is_none() {
        // Purely non-nanoswarm row, nothing to enforce.
        return Ok(());
    }
    if meta.nanoswarm_corridor_id.as_ref().map(|s| s.trim().is_empty()).unwrap_or(true) {
        return Err("nanoswarm row missing corridor_id".to_string());
    }
    if meta.nanoswarm_guard_hash.as_ref().map(|s| s.trim().is_empty()).unwrap_or(true) {
        return Err("nanoswarm row missing guard_hash".to_string());
    }
    Ok(())
}

fn persist_vampiric_aln_shard(
    date_ymd: &str,
    envelope: &VampiricHealthcareEnvelope,
) -> Result<(), String> {
    // This is the daily vampiric-health-envelope.daily.v1.aln equivalent, but in JSON form
    // for the SQL / Organichain pipeline; the true ALN text shard is generated elsewhere.
    let shard = serde_json::json!({
        "shard_type": "vampiric-health-envelope.daily.v1",
        "date_ymd": date_ymd,
        "host_did": HOST_DID,
        "bostrom_address": BOSTROM_ADDRESS,
        "aln_migration_clause": ALN_MIGRATION_CLAUSE,
        "blood_token_daily_max": envelope.blood_token_daily_max,
        "protein_token_daily_max": envelope.protein_token_daily_max,
        "lifeforce_daily_max": envelope.lifeforce_daily_max,
        "pain_threshold_vas": envelope.pain_threshold_vas,
        "fear_threshold_score": envelope.fear_threshold_score,
        "no_rollback": true,
        "no_downgrade": true
    });

    let out_name = format!("vampiric-health-envelope.daily.{}.json", date_ymd);
    let out_path = PathBuf::from(out_name);
    std::fs::write(&out_path, serde_json::to_vec_pretty(&shard).map_err(|e| e.to_string())?)
        .map_err(|e| format!("failed to write {}: {}", out_path.display(), e))?;
    Ok(())
}

fn persist_daily_summary(
    manifest: &ResearchManifest,
    state: &EvolutionWindowState,
) -> Result<(), String> {
    let today = Utc::now().date_naive().to_string();
    let summary = serde_json::json!({
        "date_ymd": manifest.date_ymd,
        "date_recorded": today,
        "host_did": manifest.host_did,
        "bostrom_address": manifest.bostrom_address,
        "roh_ceiling": manifest.roh_ceiling,
        "roh_max_observed": state.roh_max_observed,
        "approved_upgrade_ids": state.approved_upgrade_ids,
        "total_energy_joules": state.total_energy_joules,
        "total_duty_fraction": state.total_duty_fraction,
        "daily_blood_used": state.daily_blood_used,
        "daily_protein_used": state.daily_protein_used,
        "daily_lifeforce_used": state.daily_lifeforce_used,
        "no_rollback": true,
        "no_downgrade": true,
        "aln_migration_clause": ALN_MIGRATION_CLAUSE
    });

    let out_path = PathBuf::from("evolution-summary-latest.json");
    std::fs::write(&out_path, serde_json::to_vec_pretty(&summary).map_err(|e| e.to_string())?)
        .map_err(|e| format!("failed to write {}: {}", out_path.display(), e))?;
    Ok(())
}
