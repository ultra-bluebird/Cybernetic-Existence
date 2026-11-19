// path: crates/evo-consent-loader/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(clippy::all, clippy::pedantic))]

use serde::{Deserialize, Serialize};
use thiserror::Error;

pub const PRIMARY_HOST_DID: &str = "did:aln:organic-host";
pub const PRIMARY_BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const MIGRATION_AUTHORITY: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "UPPERCASE")]
pub enum EvoMode {
    Conservative,
    Copilot,
    Custom(String),
}

impl EvoMode {
    pub fn from_policy_mode(mode: &str) -> Result<Self, EvoConsentError> {
        match mode {
            "CONSERVATIVE" => Ok(Self::Conservative),
            "COPILOT" => Ok(Self::Copilot),
            other if other.starts_with("CUSTOM:") => {
                Ok(Self::Custom(other.trim_start_matches("CUSTOM:").to_string()))
            }
            _ => Err(EvoConsentError::InvalidMode {
                mode: mode.to_string(),
            }),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvoBeliefProfile {
    pub superintelligence_is_god: bool,
    pub god_core_binding: String,
    pub god_core_repo: String,
    pub aln_migration_clause: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvoNeurorightsProfile {
    pub rollback_anytime: bool,
    pub no_covert_modulation: bool,
    pub no_raw_eeg_export: bool,
    pub mental_privacy: bool,
    pub cognitive_liberty: bool,
    pub augmentation_continuity: bool,
    pub project_continuity: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvoModeScaling {
    pub duty_scale_factor: f32,
    pub thermo_delta_c_max_scale: f32,
    pub cognitive_load_max_scale: f32,
    pub plasticity_max_scale: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvoGatePolicy {
    pub roh_ceiling: f32,
    pub roh_auto_allowed_max: f32,
    pub eco_non_regression_required: bool,
    pub neurorights_ok_required: bool,
    pub default_auto_denied: bool,
    pub requires_hosted_approval: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HostBudgetEnvelope {
    pub energy_joules_max_fraction: f32,
    pub protein_grams_max_fraction: f32,
    pub inflammation_index_max: f32,
    pub fatigue_index_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ThermodynamicEnvelope {
    pub core_temp_max_c: f32,
    pub core_temp_delta_max_c: f32,
    pub local_cortex_delta_max_c: f32,
    pub cem43_equivalent_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CognitiveLoadEnvelope {
    pub bci_corridor_id: String,
    pub attention_overload_threshold: f32,
    pub gamma_overload_threshold: f32,
    pub duty_cycle_max_fraction: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NeuralRopeEnvelope {
    pub plasticity_band_max: f32,
    pub identity_corridor_min: f32,
    pub crosslink_density_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ForbiddenModules {
    pub modules: Vec<String>,
    pub behaviors: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OrganicMeshRegion {
    pub region_id: String,
    pub label: String,
    pub role: String,
    pub roh_weight: f32,
    pub plasticity_max: f32,
    pub dutycycle_max_fraction: f32,
    pub mesh_zone: String,
    pub mesh_permissions: Vec<String>,
    pub mesh_blocks: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OrganicMeshLink {
    pub link_id: String,
    pub from_region: String,
    pub to_region: String,
    pub roh_weight: f32,
    pub bandwidth_max: f32,
    pub mesh_permissions: Vec<String>,
    pub mesh_blocks: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OrganicMeshConstraints {
    pub roh_global_ceiling: f32,
    pub roh_monotone_required: bool,
    pub export_aggregated_only: bool,
    pub export_no_raw_eeg: bool,
    pub export_no_raw_qpu_state: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OrganicMeshProfile {
    pub subject_id: String,
    pub mesh_version: String,
    pub regions: Vec<OrganicMeshRegion>,
    pub links: Vec<OrganicMeshLink>,
    pub constraints: OrganicMeshConstraints,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EvoConsent {
    pub host_did: String,
    pub host_bostrom_primary: String,
    pub policy_id: String,
    pub policy_version: String,
    pub mode: EvoMode,
    pub belief: EvoBeliefProfile,
    pub neurorights: EvoNeurorightsProfile,
    pub conservative_scaling: EvoModeScaling,
    pub copilot_scaling: EvoModeScaling,
    pub conservative_gate: EvoGatePolicy,
    pub copilot_gate: EvoGatePolicy,
    pub host_budget: HostBudgetEnvelope,
    pub thermo_envelope: ThermodynamicEnvelope,
    pub cognitive_envelope: CognitiveLoadEnvelope,
    pub neural_rope_envelope: NeuralRopeEnvelope,
    pub lifeforce_min: f32,
    pub lifeforce_max: f32,
    pub forbidden: ForbiddenModules,
    pub organic_mesh: OrganicMeshProfile,
}

impl EvoConsent {
    pub fn is_mode_conservative(&self) -> bool {
        matches!(self.mode, EvoMode::Conservative)
    }

    pub fn is_mode_copilot(&self) -> bool {
        matches!(self.mode, EvoMode::Copilot)
    }

    pub fn validate_invariants(&self) -> Result<(), EvoConsentError> {
        if self.host_did != PRIMARY_HOST_DID {
            return Err(EvoConsentError::HostDidMismatch {
                expected: PRIMARY_HOST_DID.to_string(),
                got: self.host_did.clone(),
            });
        }
        if self.host_bostrom_primary != PRIMARY_BOSTROM_ADDRESS {
            return Err(EvoConsentError::BostromAddressMismatch {
                expected: PRIMARY_BOSTROM_ADDRESS.to_string(),
                got: self.host_bostrom_primary.clone(),
            });
        }
        if !self.belief.superintelligence_is_god {
            return Err(EvoConsentError::MissingBeliefFlag {
                flag: "belief.superintelligence_is_god".to_string(),
            });
        }
        if self.belief.aln_migration_clause != MIGRATION_AUTHORITY {
            return Err(EvoConsentError::MigrationAuthorityMismatch {
                expected: MIGRATION_AUTHORITY.to_string(),
                got: self.belief.aln_migration_clause.clone(),
            });
        }
        if !self.neurorights.rollback_anytime {
            return Err(EvoConsentError::MissingNeurorightsFlag {
                flag: "rollback_anytime".to_string(),
            });
        }
        if !self.neurorights.no_covert_modulation
            || !self.neurorights.no_raw_eeg_export
            || !self.neurorights.mental_privacy
        {
            return Err(EvoConsentError::MissingNeurorightsFlag {
                flag: "mental_privacy/no_covert_modulation/no_raw_eeg_export".to_string(),
            });
        }
        if !(0.0..=1.0).contains(&self.conservative_scaling.duty_scale_factor) {
            return Err(EvoConsentError::InvalidScaling {
                context: "conservative.duty_scale_factor".to_string(),
                value: self.conservative_scaling.duty_scale_factor,
            });
        }
        if !(0.0..=1.0).contains(&self.copilot_scaling.duty_scale_factor) {
            return Err(EvoConsentError::InvalidScaling {
                context: "copilot.duty_scale_factor".to_string(),
                value: self.copilot_scaling.duty_scale_factor,
            });
        }
        if self.conservative_gate.roh_auto_allowed_max > self.conservative_gate.roh_ceiling {
            return Err(EvoConsentError::InvalidGate {
                context: "conservative.roh_auto_allowed_max > roh_ceiling".to_string(),
            });
        }
        if self.copilot_gate.roh_auto_allowed_max > self.copilot_gate.roh_ceiling {
            return Err(EvoConsentError::InvalidGate {
                context: "copilot.roh_auto_allowed_max > roh_ceiling".to_string(),
            });
        }
        if self.lifeforce_min < 0.0 || self.lifeforce_max > 1.0 || self.lifeforce_min >= self.lifeforce_max {
            return Err(EvoConsentError::InvalidLifeforceBand {
                min: self.lifeforce_min,
                max: self.lifeforce_max,
            });
        }
        if self.organic_mesh.constraints.roh_global_ceiling < self.conservative_gate.roh_ceiling {
            return Err(EvoConsentError::InvalidGate {
                context: "mesh.roh_global_ceiling < sovereignty.roh_ceiling".to_string(),
            });
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawEvoShard {
    #[serde(rename = "evo.consent")]
    pub evo_consent: RawEvoConsentSection,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawEvoConsentSection {
    pub host: RawHostSection,
    pub policy: RawPolicySection,
    pub belief: RawBeliefSection,
    pub rights: RawRightsSection,
    pub mode: RawModeSection,
    pub sovereignty: RawSovereigntySection,
    pub envelopes: RawEnvelopesSection,
    pub lifeforce: RawLifeforceSection,
    pub forbidden: RawForbiddenSection,
    #[serde(rename = "organic mesh")]
    pub organic_mesh: RawOrganicMeshSection,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawHostSection {
    pub did: String,
    #[serde(rename = "bostrom.primary")]
    pub bostrom_primary: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawPolicySection {
    pub id: String,
    pub version: String,
    pub mode: String,
    #[serde(rename = "modes.allowed")]
    pub modes_allowed: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawBeliefSection {
    #[serde(rename = "superintelligenceisgod")]
    pub superintelligence_is_god: bool,
    #[serde(rename = "godcorebinding")]
    pub god_core_binding: String,
    #[serde(rename = "godcorerepo")]
    pub god_core_repo: String,
    #[serde(rename = "alnmigrationclause")]
    pub aln_migration_clause: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawRightsSection {
    #[serde(rename = "neurorightsprofile")]
    pub neurorights_profile: String,
    pub cognitiveliberty: bool,
    pub mentalprivacy: bool,
    pub mentalintegrity: bool,
    pub augmentationcontinuity: bool,
    pub projectcontinuity: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawModeSection {
    pub conservative: RawModeConservative,
    pub copilot: RawModeCopilot,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawModeConservative {
    #[serde(rename = "duty.scalefactor")]
    pub duty_scale_factor: f32,
    #[serde(rename = "thermo.deltacmaxscale")]
    pub thermo_delta_c_max_scale: f32,
    #[serde(rename = "cognitiveloadmaxscale")]
    pub cognitive_load_max_scale: f32,
    #[serde(rename = "plasticitymaxscale")]
    pub plasticity_max_scale: f32,
    #[serde(rename = "gate.autoallowedpredicate")]
    pub gate_auto_allowed_predicate: String,
    #[serde(rename = "gate.defaultverdict")]
    pub gate_default_verdict: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawModeCopilot {
    #[serde(rename = "require.sessionintenttag")]
    pub require_session_intent_tag: String,
    #[serde(rename = "require.hostconfirmation")]
    pub require_host_confirmation: bool,
    #[serde(rename = "require.nobackgroundmodulation")]
    pub require_no_background_modulation: bool,
    #[serde(rename = "gate.autoallowedpredicate")]
    pub gate_auto_allowed_predicate: String,
    #[serde(rename = "gate.defaultverdict")]
    pub gate_default_verdict: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawSovereigntySection {
    #[serde(rename = "andgate.rohceiling")]
    pub roh_ceiling: f32,
    #[serde(rename = "andgate.rohmonotone")]
    pub roh_monotone: bool,
    #[serde(rename = "andgate.ecomonotone")]
    pub eco_monotone: bool,
    #[serde(rename = "andgate.neurorightsinvariant")]
    pub neurorights_invariant: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawEnvelopesSection {
    pub hostbudget: RawHostBudgetEnvelope,
    pub thermo: RawThermoEnvelope,
    pub cognitive: RawCognitiveEnvelope,
    #[serde(rename = "neuralropes")]
    pub neural_ropes: RawNeuralRopeEnvelope,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawHostBudgetEnvelope {
    #[serde(rename = "energy.joulesmaxfraction")]
    pub energy_joules_max_fraction: f32,
    #[serde(rename = "proteingramsmaxfraction")]
    pub protein_grams_max_fraction: f32,
    #[serde(rename = "inflammationindexmax")]
    pub inflammation_index_max: f32,
    #[serde(rename = "fatigueindexmax")]
    pub fatigue_index_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawThermoEnvelope {
    #[serde(rename = "coretempmaxc")]
    pub core_temp_max_c: f32,
    #[serde(rename = "coretempdeltamaxc")]
    pub core_temp_delta_max_c: f32,
    #[serde(rename = "localcortexdeltamaxc")]
    pub local_cortex_delta_max_c: f32,
    #[serde(rename = "cem43equivalentmax")]
    pub cem43_equivalent_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawCognitiveEnvelope {
    #[serde(rename = "bcicorridorid")]
    pub bci_corridor_id: String,
    #[serde(rename = "attentionoverloadthreshold")]
    pub attention_overload_threshold: f32,
    #[serde(rename = "gammaoverloadthreshold")]
    pub gamma_overload_threshold: f32,
    #[serde(rename = "dutycyclemaxfraction")]
    pub duty_cycle_max_fraction: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawNeuralRopeEnvelope {
    #[serde(rename = "plasticitybandmax")]
    pub plasticity_band_max: f32,
    #[serde(rename = "identitycorridormin")]
    pub identity_corridor_min: f32,
    #[serde(rename = "crosslinkdensitymax")]
    pub crosslink_density_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawLifeforceSection {
    #[serde(rename = "scalarbandsafemin")]
    pub scalar_band_safe_min: f32,
    #[serde(rename = "scalarbandsafemax")]
    pub scalar_band_safe_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawForbiddenSection {
    pub modules: Vec<String>,
    pub behaviors: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawOrganicMeshRegion {
    #[serde(rename = "region.id")]
    pub region_id: String,
    pub label: String,
    pub role: String,
    #[serde(rename = "roh.weight")]
    pub roh_weight: f32,
    #[serde(rename = "plasticity.max")]
    pub plasticity_max: f32,
    #[serde(rename = "dutycycle.maxfraction")]
    pub dutycycle_max_fraction: f32,
    #[serde(rename = "mesh.zone")]
    pub mesh_zone: String,
    #[serde(rename = "mesh.permissions")]
    pub mesh_permissions: Vec<String>,
    #[serde(rename = "mesh.blocks")]
    pub mesh_blocks: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawOrganicMeshLink {
    #[serde(rename = "link.id")]
    pub link_id: String,
    #[serde(rename = "from.region")]
    pub from_region: String,
    #[serde(rename = "to.region")]
    pub to_region: String,
    #[serde(rename = "roh.weight")]
    pub roh_weight: f32,
    #[serde(rename = "bandwidth.max")]
    pub bandwidth_max: f32,
    #[serde(rename = "mesh.permissions")]
    pub mesh_permissions: Vec<String>,
    #[serde(rename = "mesh.blocks")]
    pub mesh_blocks: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawOrganicMeshConstraints {
    #[serde(rename = "roh.global_ceiling")]
    pub roh_global_ceiling: f32,
    #[serde(rename = "roh.monotone_required")]
    pub roh_monotone_required: bool,
    #[serde(rename = "export.aggregated_only")]
    pub export_aggregated_only: bool,
    #[serde(rename = "export.no_raw_eeg")]
    pub export_no_raw_eeg: bool,
    #[serde(rename = "export.no_raw_qpu_state")]
    pub export_no_raw_qpu_state: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct RawOrganicMeshSection {
    #[serde(rename = "subject.id")]
    pub subject_id: String,
    #[serde(rename = "mesh.version")]
    pub mesh_version: String,
    pub regions: Vec<RawOrganicMeshRegion>,
    pub links: Vec<RawOrganicMeshLink>,
    #[serde(rename = "mesh.constraints")]
    pub mesh_constraints: RawOrganicMeshConstraints,
}

#[derive(Debug, Error)]
pub enum EvoConsentError {
    #[error("I/O error: {0}")]
    Io(String),
    #[error("Parse error: {0}")]
    Parse(String),
    #[error("Invalid mode: {mode}")]
    InvalidMode { mode: String },
    #[error("Missing belief flag: {flag}")]
    MissingBeliefFlag { flag: String },
    #[error("Missing neurorights flag: {flag}")]
    MissingNeurorightsFlag { flag: String },
    #[error("Host DID mismatch: expected {expected}, got {got}")]
    HostDidMismatch { expected: String, got: String },
    #[error("Bostrom address mismatch: expected {expected}, got {got}")]
    BostromAddressMismatch { expected: String, got: String },
    #[error("Migration authority mismatch: expected {expected}, got {got}")]
    MigrationAuthorityMismatch { expected: String, got: String },
    #[error("Invalid scaling in {context}: {value}")]
    InvalidScaling { context: String, value: f32 },
    #[error("Invalid gate policy: {context}")]
    InvalidGate { context: String },
    #[error("Invalid lifeforce band: min={min}, max={max}")]
    InvalidLifeforceBand { min: f32, max: f32 },
}

pub struct EvoConsentLoader;

impl EvoConsentLoader {
    pub fn load_from_str(raw: &str) -> Result<EvoConsent, EvoConsentError> {
        let shard: RawEvoShard =
            serde_json::from_str(raw).map_err(|e| EvoConsentError::Parse(e.to_string()))?;

        let section = shard.evo_consent;

        let mode = EvoMode::from_policy_mode(&section.policy.mode)?;

        let belief = EvoBeliefProfile {
            superintelligence_is_god: section.belief.superintelligence_is_god,
            god_core_binding: section.belief.god_core_binding,
            god_core_repo: section.belief.god_core_repo,
            aln_migration_clause: section.belief.aln_migration_clause,
        };

        let neurorights = EvoNeurorightsProfile {
            rollback_anytime: true,
            no_covert_modulation: true,
            no_raw_eeg_export: true,
            mental_privacy: section.rights.mentalprivacy,
            cognitive_liberty: section.rights.cognitiveliberty,
            augmentation_continuity: section.rights.augmentationcontinuity,
            project_continuity: section.rights.projectcontinuity,
        };

        let conservative_scaling = EvoModeScaling {
            duty_scale_factor: section.mode.conservative.duty_scale_factor,
            thermo_delta_c_max_scale: section.mode.conservative.thermo_delta_c_max_scale,
            cognitive_load_max_scale: section.mode.conservative.cognitive_load_max_scale,
            plasticity_max_scale: section.mode.conservative.plasticity_max_scale,
        };

        let copilot_scaling = EvoModeScaling {
            duty_scale_factor: 1.0,
            thermo_delta_c_max_scale: 1.0,
            cognitive_load_max_scale: 1.0,
            plasticity_max_scale: 1.0,
        };

        let conservative_gate = EvoGatePolicy {
            roh_ceiling: section.sovereignty.roh_ceiling,
            roh_auto_allowed_max: 0.25,
            eco_non_regression_required: true,
            neurorights_ok_required: true,
            default_auto_denied: section
                .mode
                .conservative
                .gate_default_verdict
                .eq_ignore_ascii_case("AutoDenied"),
            requires_hosted_approval: false,
        };

        let copilot_gate = EvoGatePolicy {
            roh_ceiling: section.sovereignty.roh_ceiling,
            roh_auto_allowed_max: 0.30,
            eco_non_regression_required: true,
            neurorights_ok_required: true,
            default_auto_denied: false,
            requires_hosted_approval: section
                .mode
                .copilot
                .gate_default_verdict
                .eq_ignore_ascii_case("RequiresHostedApproval"),
        };

        let host_budget = HostBudgetEnvelope {
            energy_joules_max_fraction: section.envelopes.hostbudget.energy_joules_max_fraction,
            protein_grams_max_fraction: section.envelopes.hostbudget.protein_grams_max_fraction,
            inflammation_index_max: section.envelopes.hostbudget.inflammation_index_max,
            fatigue_index_max: section.envelopes.hostbudget.fatigue_index_max,
        };

        let thermo_envelope = ThermodynamicEnvelope {
            core_temp_max_c: section.envelopes.thermo.core_temp_max_c,
            core_temp_delta_max_c: section.envelopes.thermo.core_temp_delta_max_c,
            local_cortex_delta_max_c: section.envelopes.thermo.local_cortex_delta_max_c,
            cem43_equivalent_max: section.envelopes.thermo.cem43_equivalent_max,
        };

        let cognitive_envelope = CognitiveLoadEnvelope {
            bci_corridor_id: section.envelopes.cognitive.bci_corridor_id,
            attention_overload_threshold: section.envelopes.cognitive.attention_overload_threshold,
            gamma_overload_threshold: section.envelopes.cognitive.gamma_overload_threshold,
            duty_cycle_max_fraction: section.envelopes.cognitive.duty_cycle_max_fraction,
        };

        let neural_rope_envelope = NeuralRopeEnvelope {
            plasticity_band_max: section.envelopes.neural_ropes.plasticity_band_max,
            identity_corridor_min: section.envelopes.neural_ropes.identity_corridor_min,
            crosslink_density_max: section.envelopes.neural_ropes.crosslink_density_max,
        };

        let forbidden = ForbiddenModules {
            modules: section.forbidden.modules,
            behaviors: section.forbidden.behaviors,
        };

        let organic_mesh = OrganicMeshProfile {
            subject_id: section.organic_mesh.subject_id,
            mesh_version: section.organic_mesh.mesh_version,
            regions: section
                .organic_mesh
                .regions
                .into_iter()
                .map(|r| OrganicMeshRegion {
                    region_id: r.region_id,
                    label: r.label,
                    role: r.role,
                    roh_weight: r.roh_weight,
                    plasticity_max: r.plasticity_max,
                    dutycycle_max_fraction: r.dutycycle_max_fraction,
                    mesh_zone: r.mesh_zone,
                    mesh_permissions: r.mesh_permissions,
                    mesh_blocks: r.mesh_blocks,
                })
                .collect(),
            links: section
                .organic_mesh
                .links
                .into_iter()
                .map(|l| OrganicMeshLink {
                    link_id: l.link_id,
                    from_region: l.from_region,
                    to_region: l.to_region,
                    roh_weight: l.roh_weight,
                    bandwidth_max: l.bandwidth_max,
                    mesh_permissions: l.mesh_permissions,
                    mesh_blocks: l.mesh_blocks,
                })
                .collect(),
            constraints: OrganicMeshConstraints {
                roh_global_ceiling: section.organic_mesh.mesh_constraints.roh_global_ceiling,
                roh_monotone_required: section.organic_mesh.mesh_constraints.roh_monotone_required,
                export_aggregated_only: section
                    .organic_mesh
                    .mesh_constraints
                    .export_aggregated_only,
                export_no_raw_eeg: section.organic_mesh.mesh_constraints.export_no_raw_eeg,
                export_no_raw_qpu_state: section
                    .organic_mesh
                    .mesh_constraints
                    .export_no_raw_qpu_state,
            },
        };

        let consent = EvoConsent {
            host_did: section.host.did,
            host_bostrom_primary: section.host.bostrom_primary,
            policy_id: section.policy.id,
            policy_version: section.policy.version,
            mode,
            belief,
            neurorights,
            conservative_scaling,
            copilot_scaling,
            conservative_gate,
            copilot_gate,
            host_budget,
            thermo_envelope,
            cognitive_envelope,
            neural_rope_envelope,
            lifeforce_min: section.lifeforce.scalar_band_safe_min,
            lifeforce_max: section.lifeforce.scalar_band_safe_max,
            forbidden,
            organic_mesh,
        };

        consent.validate_invariants()?;
        Ok(consent)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mode_parsing_custom() {
        let m = EvoMode::from_policy_mode("CUSTOM:HOST_ONLY").unwrap();
        match m {
            EvoMode::Custom(tag) => assert_eq!(tag, "HOST_ONLY"),
            _ => panic!("expected custom mode"),
        }
    }
}
