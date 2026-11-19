use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use crate::error::PopmathError;
use crate::provenance::{AggregationStatus, DataClassification, ProvenanceRecord};
use crate::simulation::{DeterministicRng, RandomSeed};
use crate::units::EnergyKwh;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PrivacyBudgetEpsilon {
    value: PositiveF64,
}

impl PrivacyBudgetEpsilon {
    pub fn new(value: PositiveF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EnergyContributionBound {
    value: NonNegativeF64,
}

impl EnergyContributionBound {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AggregateEnergyBin {
    pub time_bin_index: u32,
    pub baseline_demand_kwh: EnergyKwh,
    pub clipped_contribution_sum_kwh: EnergyKwh,
    pub noise_kwh: f64,
    pub released_demand_kwh: EnergyKwh,
    pub contributor_count: u64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct AggregateDemandRelease {
    pub epsilon: PrivacyBudgetEpsilon,
    pub contribution_bound: EnergyContributionBound,
    pub source_provenance: ProvenanceRecord,
    pub bins: Vec<AggregateEnergyBin>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AggregateDemandInput {
    pub seed: RandomSeed,
    pub epsilon: PrivacyBudgetEpsilon,
    pub contribution_bound: EnergyContributionBound,
}

pub fn clip_energy_contribution(
    contribution_kwh: NonNegativeF64,
    bound: EnergyContributionBound,
) -> NonNegativeF64 {
    NonNegativeF64::new(
        contribution_kwh.value().min(bound.value()),
    )
    .expect("clipped non-negative contribution remains non-negative")
}

pub fn release_aggregate_energy_demand(
    input: AggregateDemandInput,
    provenance: ProvenanceRecord,
    baseline_demand_kwh: EnergyKwh,
    contributions_kwh: &[NonNegativeF64],
    time_bin_index: u32,
) -> Result<AggregateDemandRelease, PopmathError> {
    if provenance.aggregation_status != AggregationStatus::VerifiedAggregate {
        return Err(PopmathError::InsufficientAggregation);
    }

    if provenance.data_classification != DataClassification::Aggregate {
        return Err(PopmathError::InsufficientAggregation);
    }

    if input.contribution_bound.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "energy contribution bound must be greater than zero",
        ));
    }

    let clipped_sum = contributions_kwh
        .iter()
        .map(|contribution| {
            clip_energy_contribution(
                *contribution,
                input.contribution_bound,
            )
            .value()
        })
        .sum::<f64>();

    let noise = deterministic_laplace_noise(
        input.seed,
        input.contribution_bound.value() / input.epsilon.value(),
    )?;

    let released_demand = (
        baseline_demand_kwh.value().value()
            + clipped_sum
            + noise
    )
    .max(0.0);

    Ok(AggregateDemandRelease {
        epsilon: input.epsilon,
        contribution_bound: input.contribution_bound,
        source_provenance: provenance,
        bins: vec![AggregateEnergyBin {
            time_bin_index,
            baseline_demand_kwh,
            clipped_contribution_sum_kwh: EnergyKwh::new(
                NonNegativeF64::new(clipped_sum)?,
            ),
            noise_kwh: noise,
            released_demand_kwh: EnergyKwh::new(
                NonNegativeF64::new(released_demand)?,
            ),
            contributor_count: contributions_kwh.len() as u64,
        }],
    })
}

pub fn aggregate_release_to_service_demand(
    release: &AggregateDemandRelease,
) -> Result<EnergyKwh, PopmathError> {
    let total = release
        .bins
        .iter()
        .map(|bin| bin.released_demand_kwh.value().value())
        .sum::<f64>();

    EnergyKwh::new(NonNegativeF64::new(total)?)
}

pub fn privacy_release_quality_factor(
    contributor_count: u64,
    expected_contributor_count: u64,
) -> Result<UnitInterval, PopmathError> {
    if expected_contributor_count == 0 {
        return Err(PopmathError::InvalidInput(
            "expected contributor count must be greater than zero",
        ));
    }

    UnitInterval::new(
        (contributor_count as f64 / expected_contributor_count as f64)
            .clamp(0.0, 1.0),
    )
}

fn deterministic_laplace_noise(
    seed: RandomSeed,
    scale: f64,
) -> Result<f64, PopmathError> {
    if !scale.is_finite() || scale <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "Laplace scale must be finite and greater than zero",
        ));
    }

    let mut rng = DeterministicRng::new(seed);
    let uniform = (
        rng.next_u64() as f64 / u64::MAX as f64
    )
    .clamp(f64::MIN_POSITIVE, 1.0 - f64::EPSILON);

    let centered = uniform - 0.5;
    let noise = -scale * centered.signum() * (1.0 - 2.0 * centered.abs()).ln();

    if !noise.is_finite() {
        return Err(PopmathError::NonFiniteValue);
    }

    Ok(noise)
}

pub fn aggregate_provenance_label(
    epsilon: PrivacyBudgetEpsilon,
    bound: EnergyContributionBound,
) -> String {
    alloc::format!(
        "aggregate-energy-release;laplace;epsilon={};contribution-bound-kwh={}",
        epsilon.value(),
        bound.value()
    )
}
