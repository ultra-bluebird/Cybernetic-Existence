//! `popmath` provides deterministic, typed mathematical primitives for
//! aggregate civic, ecological, infrastructure, and public-service scenarios.
//!
//! The crate supplies validated quantities, scenario declarations, provenance,
//! governance metadata, reproducibility digests, solver-neutral calculation
//! models, and transparent impact summaries. It is intended for explainable
//! decision support and does not operate public infrastructure or make binding
//! decisions.
//!
//! # Portability
//!
//! The core crate supports `no_std` environments through `alloc`. Enable the
//! `std` Cargo feature only for integrations that require standard-library
//! facilities.
//!
//! # Stability
//!
//! Public serialized contracts are versioned through
//! [`MODEL_SCHEMA_VERSION`], [`RESULT_ENVELOPE_VERSION`], and
//! [`POLICY_CONTRACT_VERSION`].

#![cfg_attr(not(feature = "std"), no_std)]
#![forbid(unsafe_code)]
#![deny(
    clippy::all,
    clippy::cargo,
    clippy::nursery,
    clippy::pedantic,
    missing_docs,
    rust_2018_idioms,
    unused_lifetimes,
    unused_qualifications
)]

extern crate alloc;

/// Aggregate service-access calculations.
pub mod access;

/// Deterministic lithium-ion battery capacity-fade calculations.
pub mod battery_degradation;

/// Validated finite, non-negative, positive, and interval-bounded values.
pub mod bounds;

/// Deterministic capability, evidence, and service-continuity assessments.
pub mod continuity;

pub mod continuity_embedded;

pub mod continuity_override;

pub mod continuity_sensitivity;

/// Multi-sensor corridor calibration models and spatial-field optimization inputs.
pub mod corridor_calibration;

pub mod corridor_resilience;

/// District continuity-equity constraints for infrastructure-placement models.
pub mod district_equity;

/// Continuity-based automatic-door failure-mode assessment models.
pub mod door_continuity;

/// Ecological accounting and environmental-performance calculations.
pub mod ecology;

/// Electromagnetic-interference measurements and compatibility calculations.
pub mod emi;

/// Energy storage, dispatch, critical-load, and converter-loss accounting.
pub mod energy;

/// Structured error types and crate-wide result aliases.
pub mod error;

/// Governance, permitted-use, review-requirement, and inclusion-assessment models.
pub mod governance;

pub mod green_roof;

/// Water-aware urban heat-island intervention optimization models.
pub mod heat_island;

/// Aggregate-statistics reserve sizing for public charging kiosks.
pub mod kiosk_reserve;

/// Latency-bounded network-continuity calculations.
pub mod latency;

/// Delivery-capacity and logistics feasibility calculations.
pub mod logistics;

/// Maintenance backlog and response-capacity calculations.
pub mod maintenance;

/// Continuity-aware maintenance-work state-machine models.
pub mod maintenance_fsm;

/// Accessible, continuity-aware, and energy-aware network-routing calculations.
pub mod mobility;

/// LAeq-based environmental noise compatibility calculations.
pub mod noise;

/// Solver-neutral optimization models and candidate-solution validation.
pub mod optimization;

pub mod optimization_governance;

/// Aggregate population projection and public-service demand calculations.
pub mod population;

pub mod preventive_maintenance;

/// Privacy-preserving aggregate energy-demand release calculations.
pub mod privacy_aggregate;

/// Input lineage, aggregation, classification, and quality declarations.
pub mod provenance;

/// Hash-linked provenance-chain summaries and verification functions.
pub mod provenance_chain;

/// Queue-capacity and service-level staffing calculations.
pub mod queues;

/// Reproducible result envelopes, validation status, and impact metrics.
pub mod result;

/// Immutable scenario assumptions, constraints, and objectives.
pub mod scenario;

/// Seeded Monte Carlo and deterministic sensitivity analysis.
pub mod simulation;

/// Aggregate community inclusion and public-system acceptance metrics.
pub mod social;

/// Deterministic social-acceptance feedback simulation.
pub mod social_feedback;

/// Deterministic synthetic aggregate-demand generation.
pub mod synthetic_demand;

/// UTC timestamps, durations, and half-open time windows.
pub mod time;

/// Continuity-evaluated universal-design component profiles.
pub mod universal_design;

/// Typed physical, financial, and population quantities.
pub mod units;

/// Water storage, supply, demand, loss, and recovery accounting.
pub mod water;

/// Common imports for ordinary `popmath` consumers.
///
/// This module exposes stable primary types and functions needed for scenario
/// calculations without requiring consumers to import each module repeatedly.
pub mod prelude {
    /// Aggregate service-access calculations.
    pub use crate::access::{
        calculate_service_access, ServiceAccessInput, ServiceAccessResult,
    };

    /// Battery-capacity degradation calculations.
    pub use crate::battery_degradation::{
        calculate_battery_degradation, BatteryDegradationInput,
        BatteryDegradationResult,
    };

    /// Bounded numeric values.
    pub use crate::bounds::{
        FiniteF64, NonNegativeF64, PositiveF64, Probability, Ratio, UnitInterval,
    };

    /// Continuity requirements, capability expressions, and assessments.
    pub use crate::continuity::{
        assess_continuity, assess_continuity_expression,
        CapabilityContinuityResult, CapabilityExpression, CapabilityKind,
        CapabilityRequirement, CapabilityWindow, ContinuityAssessment,
        ContinuityStatus, EvidenceStatus,
    };

    /// Corridor calibration model types.
    pub use crate::corridor_calibration::{
        build_corridor_calibration_model, CorridorBounds, CorridorCalibrationInput,
        CorridorCalibrationModel, CorridorSensorObservation, CorridorVariable,
        SpatialKnot,
    };

    /// District continuity-equity constraint models.
    pub use crate::district_equity::{
        build_district_equity_constraint_model, DistrictContinuityInput,
        DistrictEquityConstraintModel,
    };

    /// Automatic-door continuity models.
    pub use crate::door_continuity::{
        assess_automatic_door_continuity, default_door_requirements,
        DoorContinuityAssessment, DoorFailureMode, DoorFailureModeRequirement,
    };

    /// Ecological accounting calculations.
    pub use crate::ecology::{
        calculate_eco_evidence, calculate_hydraulic_efficiency,
        calculate_operational_emissions, calculate_pollutant_mass_balance,
        ConcentrationKgPerM3, Contaminant, EcoEvidenceInput, EcoEvidenceResult,
        HydraulicEfficiencyInput, HydraulicEfficiencyResult,
        OperationalEmissionsInput, OperationalEmissionsResult,
        PollutantMassBalanceInput, PollutantMassBalanceResult,
    };

    /// Electromagnetic-compatibility calculations.
    pub use crate::emi::{
        as_capability_window, dbuv_per_meter_to_volts_per_meter,
        is_emi_compatible, ElectricFieldStrengthVoltsPerMeter, EmiMeasurement,
        EmiSensitivityThreshold,
    };

    /// Energy storage, converter loss, and conservative-capacity calculations.
    pub use crate::energy::{
        build_converter_efficiency_curve, calculate_conservative_storage_capacity,
        calculate_converter_input_energy, calculate_critical_load_continuity,
        calculate_energy_storage, calculate_poe_converter_losses,
        CapacitanceCoulombs, ConservativeStorageCapacity,
        ConverterEfficiencyCurve, ConverterEfficiencyPoint,
        CriticalLoadContinuityInput, CriticalLoadContinuityResult,
        CurrentAmperes, DurationSeconds as EnergyDurationSeconds,
        EnergyStorageDegradationInput, EnergyStorageInput, EnergyStorageResult,
        FrequencyHertz, PoEConverterInput, PoEConverterLossResult, PowerWatts,
        ResistanceOhms, TriangularOutageDistribution, VoltageVolts,
    };

    /// Crate-wide error values.
    pub use crate::error::{PopmathError, PopmathResult};

    /// Governance and inclusion-assessment models.
    pub use crate::governance::{
        assess_anti_discrimination, AccessEquivalenceCheck,
        AccessRequirementClass, AntiDiscriminationAssessment,
        AntiDiscriminationStatus, DataUsePolicy, DecisionBoundary,
        GovernanceAssessment, PermittedUse, Purpose, PurposeCategory,
        ReviewRequirement,
    };

    /// Heat-island intervention optimization models.
    pub use crate::heat_island::{
        build_heat_island_optimization_model, AreaSquareMeters,
        CubicMetersPerSquareMeter, CurrencyPerSquareMeter,
        HeatIslandOptimizationInput, HeatIslandOptimizationModel,
        HeatIslandReductionPerSquareMeter,
    };

    /// Public charging reserve-sizing calculations.
    pub use crate::kiosk_reserve::{
        calculate_public_charging_kiosk_reserve, KioskReserveSizingInput,
        KioskReserveSizingResult,
    };

    /// Latency-bounded continuity calculations.
    pub use crate::latency::{
        assess_latency_window, latency_measurement_to_capability_window,
        latency_requirement_to_capability_requirement,
        LatencyMeasurementWindow, LatencyMilliseconds, LatencyRequirement,
        LatencyWindowAssessment,
    };

    /// Delivery-capacity calculations.
    pub use crate::logistics::{
        calculate_delivery_capacity, DeliveryCapacityInput, DeliveryCapacityResult,
    };

    /// Maintenance capacity calculations.
    pub use crate::maintenance::{
        calculate_maintenance_backlog, calculate_maintenance_response,
        MaintenanceBacklogInput, MaintenanceBacklogResult,
        MaintenanceResponseInput, MaintenanceResponseResult,
    };

    /// Continuity-aware maintenance state-machine calculations.
    pub use crate::maintenance_fsm::{
        evaluate_maintenance_transition, MaintenanceContinuityGuard,
        MaintenanceState, MaintenanceTransitionDecision,
        MaintenanceTransitionRequest,
    };

    /// Accessible and energy-aware mobility calculations.
    pub use crate::mobility::{
        calculate_accessible_route, calculate_aggregate_coverage,
        calculate_power_efficient_accessible_route, AccessibilityState,
        AccessibleRouteInput, AccessibleRouteResult, AggregateCoverageInput,
        AggregateCoverageResult, ChargingContinuityRequirement,
        DistanceMeters, EnergyAwareNetworkEdge, EnergyAwareRouteResult,
        NetworkEdge, NetworkNode, PoweredMobilityEnergyModel, TravelMode,
        WattHoursPerMeter, WattHoursPerMeterGrade, WattHoursPerSecond,
    };

    /// LAeq-based noise compatibility calculations.
    pub use crate::noise::{
        interpolate_corridor_noise, is_low_noise_compatible,
        noise_measurement_to_capability_window, AWeightedDecibels,
        CorridorNoisePoint, CorridorPositionMeters, NoiseMeasurementWindow,
        NoiseRequirement,
    };

    /// Solver-neutral optimization models.
    pub use crate::optimization::{
        build_candidate_result, validate_solution, AlternativeAnalysisStatus,
        ConstraintPriority, ConstraintRelation, DecisionVariable,
        LinearExpression, LinearTerm, ObjectiveDirection, ObjectiveFunction,
        OptimizationConstraint, OptimizationProblem, OptimizationResult,
        SolverStatus, VariableAssignment, VariableDomain,
    };

    /// Population and aggregate service-demand calculations.
    pub use crate::population::{
        aggregate_synthetic_service_demand, calculate_service_demand,
        project_population, AggregateServiceDemandProfile,
        PopulationProjectionInput, PopulationProjectionResult,
        ServiceDemandInput, ServiceDemandResult,
    };

    /// Privacy-preserving aggregate demand-release calculations.
    pub use crate::privacy_aggregate::{
        aggregate_provenance_label, aggregate_release_to_service_demand,
        clip_energy_contribution, privacy_release_quality_factor,
        release_aggregate_energy_demand, AggregateDemandInput,
        AggregateDemandRelease, AggregateEnergyBin, EnergyContributionBound,
        PrivacyBudgetEpsilon,
    };

    /// Provenance declarations.
    pub use crate::provenance::{
        AggregationStatus, DataClassification, DataQuality, ProvenanceRecord,
        SourceKind,
    };

    /// Hash-linked provenance-chain calculations.
    pub use crate::provenance_chain::{
        build_sensor_provenance_chain, summarize_provenance_chain,
        verify_provenance_chain, CalibrationStatus, ProvenanceChainSummary,
        SensorReadingCommitment,
    };

    /// Queue-capacity and service-level staffing calculations.
    pub use crate::queues::{
        calculate_queue_capacity, calculate_queue_service_level,
        calculate_two_class_queue_service_level, QueueCapacityInput,
        QueueCapacityResult, QueueServiceLevelInput, QueueServiceLevelResult,
        TwoClassQueueServiceLevelInput, TwoClassQueueServiceLevelResult,
    };

    /// Result-envelope and validation types.
    pub use crate::result::{
        build_result_envelope, result_evidence_is_decision_ready,
        validation_status_from_governance, ResultEnvelope,
        ResultEvidenceSummary, ResultMetrics, ValidationStatus,
    };

    /// Scenario declarations.
    pub use crate::scenario::{Assumption, Constraint, ConstraintKind, Scenario};

    /// Seeded simulation and sensitivity calculations.
    pub use crate::simulation::{
        calculate_affine_sensitivity, run_monte_carlo, DeterministicRng,
        MonteCarloInput, MonteCarloResult, RandomSeed, SensitivityInput,
        SensitivityResult, TriangularDistribution,
    };

    /// Aggregate inclusion metrics.
    pub use crate::social::{
        calculate_social_acceptance, SocialAcceptanceInput,
        SocialAcceptanceResult,
    };

    /// Social-acceptance feedback simulation.
    pub use crate::social_feedback::{
        simulate_social_acceptance_feedback, SocialFeedbackInput,
        SocialFeedbackPeriod, SocialFeedbackResult,
    };

    /// Synthetic aggregate-demand generation.
    pub use crate::synthetic_demand::{
        generate_synthetic_cohort_demand, AggregateDemandRow, AggregateZone,
        DemandTimeBin, SyntheticCohortDemandInput,
        SyntheticCohortDemandResult, SyntheticDeviceProfile,
        SyntheticDeviceType,
    };

    /// Time primitives.
    pub use crate::time::{DurationSeconds, TimeWindow, UtcTimestamp};

    /// Universal-design component profiles.
    pub use crate::universal_design::{
        assess_universal_design, default_universal_design_requirements,
        UniversalDesignAssessment, UniversalDesignCriterion,
        UniversalDesignRequirement,
    };

    /// Typed measurement and quantity values.
    pub use crate::units::{
        CurrencyAmount, CurrencyCode, DistanceM, Efficiency, EmissionsKgCo2e,
        EnergyKwh, FlowRateM3PerSecond, MassKg, PopulationCount,
        PopulationWeight, PowerKw, VolumeM3,
    };

    /// Water-accounting calculations.
    pub use crate::water::{
        calculate_water_balance, WaterBalanceInput, WaterBalanceResult,
    };
}

/// Structured error type returned by fallible `popmath` operations.
pub use error::PopmathError;

/// Crate-wide result alias for fallible `popmath` operations.
pub use error::PopmathResult;

/// Version of the stable serialized model contract.
///
/// Consumers that persist or exchange scenario and model structures should
/// retain this value with the serialized payload.
pub const MODEL_SCHEMA_VERSION: &str = "0.1";

/// Version of the common calculation-result envelope contract.
///
/// Consumers that persist or exchange [`result::ResultEnvelope`] values should
/// retain this value with the serialized payload.
pub const RESULT_ENVELOPE_VERSION: &str = "0.1";

/// Version of the governance and data-use contract.
///
/// Consumers should retain this value alongside scenario governance records to
/// make policy interpretation and future migrations explicit.
pub const POLICY_CONTRACT_VERSION: &str = "0.1";
