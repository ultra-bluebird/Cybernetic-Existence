//! nanoswarm_env_materials
//!
//! Core environment, materials, payload, electronics, ecology, and governance
//! envelopes for nanoswarm deployments, aligned with Cybercore invariants.
//!
//! This crate is designed as a host-safe core that can be used inside
//! Cybercore and nanorobotics stacks to validate nanoswarm configurations
//! against:
//! - Environment regimes (terrestrial, LEO, GEO, Mars analogue, deep space),
//! - Thermal management stacks (radiative cooling, PCM buffers, spreaders),
//! - UV shielding and self-healing coatings,
//! - Bio-nano payload stability (e.g., DNA origami),
//! - High-temperature electronics envelopes (e.g., GaN/AlGaN HEMTs),
//! - Ecology and Earth-restoration compatibility,
//! while enforcing neurorights-centric governance invariants.

#![forbid(unsafe_code)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

/// Marker for Cybercore authority.
///
/// Asserts that this crate's evolution is governed by Cybercore and that
/// mk-bluebird/Cybercore is the source of truth for migration.
pub struct CybercoreAuthority;

impl CybercoreAuthority {
    pub const MIGRATION_TAG: &'static str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
    pub const HOST_DID: &'static str = "OrganicCPU";
    pub const BOSTROM_ADDRESS: &'static str =
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
}

/// Deployment environment regimes for nanoswarm systems.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EnvironmentRegime {
    Leo,
    Geo,
    MarsSurface,
    HighUvDesert,
    DeepSpace,
}

/// High-level deployment mode, used to select policy and hard caps.
///
/// In particular, EarthRestoration activates ecology-first invariants.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DeploymentMode {
    EarthRestoration,
    TerrestrialHighUv,
    Leo,
    Geo,
    MarsAnalogue,
    DeepSpace,
}

/// Envelope describing key stressors for the space-like environment
/// (including Mars analogue and high-UV deserts for continuity of modeling).
#[derive(Debug, Clone, Copy)]
pub struct SpaceEnvironmentEnvelope {
    pub regime: EnvironmentRegime,
    /// Maximum representative UV index or normalized UV intensity (0–1).
    pub uv_index_max: f32,
    /// Relative spectral weighting of UV vs visible/IR (0–1, conceptual).
    pub uv_spectral_weight: f32,
    /// Maximum atomic oxygen flux (conceptual units),
    /// relevant mainly to LEO-style environments.
    pub ao_flux_max: f32,
    /// Maximum typical thermal cycle amplitude (ΔT in °C).
    pub thermal_cycle_delta_max: f32,
    /// Representative pressure range in kPa (e.g. ~0 for vacuum,
    /// ~0.6–1 for Martian/terrestrial environments).
    pub pressure_min_kpa: f32,
    pub pressure_max_kpa: f32,
}

/// Radiative cooling layer based on ultrawhite BaSO4 paints/films or
/// future materials.
#[derive(Debug, Clone, Copy)]
pub enum RadiativeCoolingLayerKind {
    BaSo4,
    Custom,
}

#[derive(Debug, Clone, Copy)]
pub struct RadiativeCoolingLayer {
    pub kind: RadiativeCoolingLayerKind,
    /// Hemispherical solar reflectance (0–1).
    pub solar_reflectance: f32,
    /// Emissivity in the atmospheric window (0–1).
    pub sky_window_emissivity: f32,
    /// Observed sub-ambient temperature (°C below ambient) under nominal
    /// test conditions, if known.
    pub sub_ambient_cooling_c: f32,
    /// Approximate cooling power in W/m² under strong sun, if known.
    pub cooling_power_w_m2: f32,
}

/// Phase-change material (PCM) based thermal buffer with nanoparticle
/// enhancement, modeled generically.
#[derive(Debug, Clone, Copy)]
pub struct ThermalBufferLayer {
    /// Latent heat of fusion (J/kg).
    pub latent_heat_j_per_kg: f32,
    /// Effective thermal conductivity (W/m·K).
    pub thermal_conductivity_w_per_mk: f32,
    /// Fractional capacity retained after many cycles (0–1).
    pub cycling_stability: f32,
}

/// High-conductivity spreader layer (e.g., graphene-polymer composite).
#[derive(Debug, Clone, Copy)]
pub struct ThermalSpreaderLayer {
    /// In-plane thermal conductivity (W/m·K).
    pub in_plane_conductivity_w_per_mk: f32,
    /// Through-thickness thermal conductivity (W/m·K).
    pub through_thickness_conductivity_w_per_mk: f32,
}

/// Full thermal stack for nanoswarm modules.
#[derive(Debug, Clone, Copy)]
pub struct ThermalStack {
    pub radiative: RadiativeCoolingLayer,
    pub buffer: Option<ThermalBufferLayer>,
    pub spreader: Option<ThermalSpreaderLayer>,
}

impl ThermalStack {
    /// Check that a given operating junction temperature is within a
    /// specified envelope for electronics or bio-nano payloads.
    pub fn is_temp_within(&self, t_celsius: f32, t_min: f32, t_max: f32) -> bool {
        t_celsius >= t_min && t_celsius <= t_max
    }
}

/// UV shielding layer types used on nanoswarm surfaces.
#[derive(Debug, Clone, Copy)]
pub enum UvShieldLayerKind {
    BaSo4Radiative,
    CeO2Coating,
    MelaninNpFilm,
    Custom,
}

/// UV shield layer with generic properties.
///
/// uv_blocking_efficiency and biocompatibility_score are normalized
/// scalars (0–1) to be calibrated with experimental data.
#[derive(Debug, Clone, Copy)]
pub struct UvShieldLayer {
    pub kind: UvShieldLayerKind,
    pub uv_blocking_efficiency: f32,
    pub biocompatibility_score: f32,
    /// Healing capability (0–1), non-zero for self-healing polymers.
    pub healing_capability: f32,
}

/// UV-triggered self-healing coating properties.
#[derive(Debug, Clone, Copy)]
pub struct SelfHealingCoating {
    /// Maximum number of healing cycles before degradation of performance.
    pub max_healing_cycles: u32,
    /// UV dose required per healing event (arbitrary units, to be mapped
    /// to test protocols like xenon-arc).
    pub healing_trigger_uv_dose: f32,
    /// Fraction of barrier function recovered per healing event (0–1).
    pub barrier_recovery_fraction: f32,
}

/// DNA origami (or similar DNA-based constructs) stability envelope.
#[derive(Debug, Clone, Copy)]
pub struct DnaOrigamiStability {
    /// Minimum safe operating temperature (°C).
    pub t_min_c: f32,
    /// Maximum safe operating temperature (°C).
    pub t_max_c: f32,
    /// Maximum allowed "denaturant index" (0–1), an abstract scalar that
    /// can map to concentration of urea, formamide, etc.
    pub denaturant_index_max: f32,
    /// Whether enzymatic ligation is required to meet this envelope.
    pub requires_enzymatic_ligation: bool,
}

/// Generic bio-nano payload with an associated stability envelope.
#[derive(Debug, Clone)]
pub struct BioNanoPayload<S> {
    pub stability: S,
    /// Abstract payload identifier or description.
    pub label: &'static str,
}

impl<S> BioNanoPayload<S> {
    pub fn new(stability: S, label: &'static str) -> Self {
        Self { stability, label }
    }
}

/// High-temperature electronics envelope (e.g., GaN/AlGaN HEMTs).
#[derive(Debug, Clone, Copy)]
pub struct HighTempElectronicsEnvelope {
    /// Minimum and maximum junction temperatures (°C).
    pub t_junction_min_c: f32,
    pub t_junction_max_c: f32,
    /// Maximum allowed power density (W/mm² or similar units).
    pub max_power_density: f32,
    /// Maximum acceptable leakage current density (A/mm or normalized).
    pub leakage_limit: f32,
}

/// UV exposure metric with conceptual mapping from xenon-arc tests
/// to environmental exposure budgets.
#[derive(Debug, Clone, Copy)]
pub struct UvExposureMetric {
    pub environment: EnvironmentRegime,
    /// Hours in xenon-arc accelerated test.
    pub xenon_arc_hours: f32,
    /// Conceptual equivalent solar hours in the target environment.
    pub equivalent_solar_hours: f32,
}

impl UvExposureMetric {
    /// Construct a metric from xenon-arc test duration and a simple,
    /// environment-dependent scaling factor.
    ///
    /// The scaling factors should be calibrated externally with
    /// experimental data; here we provide the type and a basic hook.
    pub fn from_xenon_arc(
        environment: EnvironmentRegime,
        xenon_arc_hours: f32,
        scaling_factor: f32,
    ) -> Self {
        Self {
            environment,
            xenon_arc_hours,
            equivalent_solar_hours: xenon_arc_hours * scaling_factor,
        }
    }
}

/// Ecology and Earth-restoration compatibility profile.
#[derive(Debug, Clone, Copy)]
pub struct EcologyCompatibilityProfile {
    /// Biodegradation half-life in days.
    pub biodegradation_half_life_days: f32,
    /// Ecotoxicity score (0–1), where 0 is negligible and 1 is severe.
    pub ecotoxicity_score: f32,
    /// Microbiome disruption index (0–1), lower is better.
    pub microbiome_disruption_index: f32,
    /// Persistence in soil/water (0–1), where 0 is fully transient and 1
    /// is effectively persistent.
    pub soil_water_persistence_index: f32,
}

/// Mission exposure budget for a nanoswarm configuration.
///
/// This can be extended later to include radiation fluence, AO fluence,
/// etc., but we start with UV and simple time/cycle budgets.
#[derive(Debug, Clone, Copy)]
pub struct MissionBudget {
    pub uv: UvExposureMetric,
    /// Maximum number of allowed thermal cycles over the mission.
    pub thermal_cycles_max: u32,
    /// Maximum calendar days in-service for this configuration.
    pub calendar_days_max: u32,
}

/// Core nanoswarm envelope tying together environment, materials,
/// payloads, electronics, ecology, and governance invariants.
///
/// Invariants:
/// - max_roh <= 0.3
/// - min_capability_floor >= 0.8
/// - no_rollback_without_host_token == true
/// - no_shadow_authority == true
/// - min_health_telemetry_rate_hz > 0.0
/// - If deployment_mode == EarthRestoration and ecology is Some(_):
///   - ecotoxicity_score <= 0.3
///   - microbiome_disruption_index <= 0.3
///   - soil_water_persistence_index <= 0.7
#[derive(Debug, Clone)]
pub struct NanoswarmEnvelope<S> {
    pub deployment_mode: DeploymentMode,
    pub environment: EnvironmentRegime,
    pub space_env: Option<SpaceEnvironmentEnvelope>,
    pub thermal: ThermalStack,
    pub uv_layers: Vec<UvShieldLayer>,
    pub self_healing: Option<SelfHealingCoating>,
    pub bionano_payload: Option<BioNanoPayload<S>>,
    pub electronics: Option<HighTempElectronicsEnvelope>,
    pub ecology: Option<EcologyCompatibilityProfile>,
    pub mission_budget: MissionBudget,

    pub max_roh: f32,
    pub min_capability_floor: f32,
    pub no_rollback_without_host_token: bool,

    /// Must be true: no hidden controllers or authorities.
    pub no_shadow_authority: bool,
    /// Minimum required health telemetry rate (Hz).
    pub min_health_telemetry_rate_hz: f32,

    pub host_did: &'static str,
    pub bostrom_address: &'static str,
    pub authority_tag: &'static str,
}

#[derive(Debug)]
pub enum NanoswarmEnvelopeError {
    MaxRohTooHigh(f32),
    CapabilityFloorTooLow(f32),
    RollbackFlagInvalid,
    ShadowAuthorityNotAllowed,
    TelemetryRateTooLow(f32),
    EcologyEcotoxicityTooHigh(f32),
    EcologyMicrobiomeDisruptionTooHigh(f32),
    EcologyPersistenceTooHigh(f32),
}

impl<S> NanoswarmEnvelope<S> {
    /// Construct a new NanoswarmEnvelope while enforcing neurorights,
    /// ecology, and governance invariants.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        deployment_mode: DeploymentMode,
        environment: EnvironmentRegime,
        space_env: Option<SpaceEnvironmentEnvelope>,
        thermal: ThermalStack,
        uv_layers: Vec<UvShieldLayer>,
        self_healing: Option<SelfHealingCoating>,
        bionano_payload: Option<BioNanoPayload<S>>,
        electronics: Option<HighTempElectronicsEnvelope>,
        ecology: Option<EcologyCompatibilityProfile>,
        mission_budget: MissionBudget,
        max_roh: f32,
        min_capability_floor: f32,
        no_rollback_without_host_token: bool,
        no_shadow_authority: bool,
        min_health_telemetry_rate_hz: f32,
    ) -> Result<Self, NanoswarmEnvelopeError> {
        if max_roh > 0.3 {
            return Err(NanoswarmEnvelopeError::MaxRohTooHigh(max_roh));
        }
        if min_capability_floor < 0.8 {
            return Err(NanoswarmEnvelopeError::CapabilityFloorTooLow(
                min_capability_floor,
            ));
        }
        if !no_rollback_without_host_token {
            return Err(NanoswarmEnvelopeError::RollbackFlagInvalid);
        }
        if !no_shadow_authority {
            return Err(NanoswarmEnvelopeError::ShadowAuthorityNotAllowed);
        }
        if min_health_telemetry_rate_hz <= 0.0 {
            return Err(NanoswarmEnvelopeError::TelemetryRateTooLow(
                min_health_telemetry_rate_hz,
            ));
        }

        if let (DeploymentMode::EarthRestoration, Some(ecology_profile)) =
            (deployment_mode, ecology)
        {
            if ecology_profile.ecotoxicity_score > 0.3 {
                return Err(
                    NanoswarmEnvelopeError::EcologyEcotoxicityTooHigh(
                        ecology_profile.ecotoxicity_score,
                    ),
                );
            }
            if ecology_profile.microbiome_disruption_index > 0.3 {
                return Err(
                    NanoswarmEnvelopeError::EcologyMicrobiomeDisruptionTooHigh(
                        ecology_profile.microbiome_disruption_index,
                    ),
                );
            }
            if ecology_profile.soil_water_persistence_index > 0.7 {
                return Err(
                    NanoswarmEnvelopeError::EcologyPersistenceTooHigh(
                        ecology_profile.soil_water_persistence_index,
                    ),
                );
            }
        }

        Ok(Self {
            deployment_mode,
            environment,
            space_env,
            thermal,
            uv_layers,
            self_healing,
            bionano_payload,
            electronics,
            ecology,
            mission_budget,
            max_roh,
            min_capability_floor,
            no_rollback_without_host_token,
            no_shadow_authority,
            min_health_telemetry_rate_hz,
            host_did: CybercoreAuthority::HOST_DID,
            bostrom_address: CybercoreAuthority::BOSTROM_ADDRESS,
            authority_tag: CybercoreAuthority::MIGRATION_TAG,
        })
    }
}

/// Convenience constructor for a BaSO4-based radiative cooling layer
/// using representative subambient performance.
pub fn default_baso4_radiative_layer() -> RadiativeCoolingLayer {
    RadiativeCoolingLayer {
        kind: RadiativeCoolingLayerKind::BaSo4,
        solar_reflectance: 0.98,
        sky_window_emissivity: 0.95,
        sub_ambient_cooling_c: 4.5,
        cooling_power_w_m2: 117.0,
    }
}
