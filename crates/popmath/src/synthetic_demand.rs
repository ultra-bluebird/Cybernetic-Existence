use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, Probability, UnitInterval};
use crate::error::PopmathError;
use crate::simulation::{DeterministicRng, RandomSeed};
use crate::units::{EnergyKwh, PopulationCount};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum SyntheticDeviceType {
    PoweredMobilitySupport,
    AssistiveCommunicationInterface,
    EnvironmentalRegulationSupport,
    MobilityStabilizationSupport,
    LocalChargingReserve,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SyntheticDeviceProfile {
    pub device_type: SyntheticDeviceType,
    pub selection_probability: Probability,
    pub operating_power_kw: NonNegativeF64,
    pub recharge_energy_kwh_per_day: NonNegativeF64,
    pub travel_participation_probability: Probability,
    pub peak_utilization: UnitInterval,
    pub off_peak_utilization: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AggregateZone {
    pub zone_index: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DemandTimeBin {
    pub bin_index: u32,
    pub duration_minutes: u32,
    pub is_peak_period: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SyntheticCohortDemandInput {
    pub seed: RandomSeed,
    pub synthetic_population: PopulationCount,
    pub zones: Vec<AggregateZone>,
    pub time_bins: Vec<DemandTimeBin>,
    pub device_profiles: Vec<SyntheticDeviceProfile>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct AggregateDemandRow {
    pub zone_index: u32,
    pub time_bin_index: u32,
    pub active_synthetic_count: PopulationCount,
    pub operating_load_kw: NonNegativeF64,
    pub recharge_energy_kwh: EnergyKwh,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SyntheticCohortDemandResult {
    pub seed: RandomSeed,
    pub synthetic_population: PopulationCount,
    pub rows: Vec<AggregateDemandRow>,
}

pub fn generate_synthetic_cohort_demand(
    input: &SyntheticCohortDemandInput,
) -> Result<SyntheticCohortDemandResult, PopmathError> {
    validate_synthetic_input(input)?;

    let mut rng = DeterministicRng::new(input.seed);
    let mut accumulator = DemandAccumulator::new(input.zones.len(), input.time_bins.len());

    for _ in 0..input.synthetic_population.value() {
        let profile = select_device_profile(&mut rng, &input.device_profiles)?;

        if !sample_probability(&mut rng, profile.travel_participation_probability) {
            continue;
        }

        let zone_index = sample_index(&mut rng, input.zones.len())?;
        let zone = input.zones[zone_index];

        for time_bin in &input.time_bins {
            let utilization = if time_bin.is_peak_period {
                profile.peak_utilization
            } else {
                profile.off_peak_utilization
            };

            if !sample_probability(&mut rng, Probability::new(utilization.value())?) {
                continue;
            }

            let duration_hours = f64::from(time_bin.duration_minutes) / 60.0;
            let operating_load_kw = profile.operating_power_kw.value();
            let recharge_energy_kwh = profile.recharge_energy_kwh_per_day.value()
                * duration_hours
                / 24.0;

            accumulator.add(
                zone.zone_index,
                time_bin.bin_index,
                operating_load_kw,
                recharge_energy_kwh,
            )?;
        }
    }

    Ok(SyntheticCohortDemandResult {
        seed: input.seed,
        synthetic_population: input.synthetic_population,
        rows: accumulator.into_rows()?,
    })
}

fn validate_synthetic_input(
    input: &SyntheticCohortDemandInput,
) -> Result<(), PopmathError> {
    if input.synthetic_population.value() == 0 {
        return Err(PopmathError::InvalidInput(
            "synthetic population must be greater than zero",
        ));
    }

    if input.zones.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one aggregate zone is required",
        ));
    }

    if input.time_bins.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one time bin is required",
        ));
    }

    if input.device_profiles.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one synthetic device profile is required",
        ));
    }

    for time_bin in &input.time_bins {
        if time_bin.duration_minutes == 0 {
            return Err(PopmathError::InvalidInput(
                "demand time-bin duration must be greater than zero",
            ));
        }
    }

    let total_probability = input
        .device_profiles
        .iter()
        .map(|profile| profile.selection_probability.value())
        .sum::<f64>();

    if (total_probability - 1.0).abs() > 1e-12 {
        return Err(PopmathError::InvalidInput(
            "synthetic device selection probabilities must sum to one",
        ));
    }

    Ok(())
}

fn select_device_profile<'a>(
    rng: &mut DeterministicRng,
    profiles: &'a [SyntheticDeviceProfile],
) -> Result<&'a SyntheticDeviceProfile, PopmathError> {
    let sample = next_unit_interval(rng)?;
    let mut cumulative_probability = 0.0;

    for profile in profiles {
        cumulative_probability += profile.selection_probability.value();

        if sample <= cumulative_probability {
            return Ok(profile);
        }
    }

    profiles.last().ok_or(PopmathError::InvalidInput(
        "at least one device profile is required",
    ))
}

fn sample_probability(
    rng: &mut DeterministicRng,
    probability: Probability,
) -> bool {
    next_unit_interval(rng)
        .map(|sample| sample <= probability.value())
        .unwrap_or(false)
}

fn sample_index(
    rng: &mut DeterministicRng,
    length: usize,
) -> Result<usize, PopmathError> {
    if length == 0 {
        return Err(PopmathError::InvalidInput(
            "sample length must be greater than zero",
        ));
    }

    let sample = next_unit_interval(rng)?;
    let index = (sample * length as f64) as usize;

    Ok(index.min(length - 1))
}

fn next_unit_interval(
    rng: &mut DeterministicRng,
) -> Result<f64, PopmathError> {
    let sample = rng.next_u64();
    let normalized = (sample as f64) / (u64::MAX as f64);

    UnitInterval::new(normalized).map(|value| value.value())
}

#[derive(Debug, Clone)]
struct DemandAccumulator {
    rows: Vec<DemandAccumulatorRow>,
}

#[derive(Debug, Clone)]
struct DemandAccumulatorRow {
    zone_index: u32,
    time_bin_index: u32,
    active_count: u64,
    operating_load_kw: f64,
    recharge_energy_kwh: f64,
}

impl DemandAccumulator {
    fn new(zone_count: usize, time_bin_count: usize) -> Self {
        Self {
            rows: Vec::with_capacity(zone_count * time_bin_count),
        }
    }

    fn add(
        &mut self,
        zone_index: u32,
        time_bin_index: u32,
        operating_load_kw: f64,
        recharge_energy_kwh: f64,
    ) -> Result<(), PopmathError> {
        if let Some(row) = self.rows.iter_mut().find(|row| {
            row.zone_index == zone_index && row.time_bin_index == time_bin_index
        }) {
            row.active_count = row
                .active_count
                .checked_add(1)
                .ok_or(PopmathError::ArithmeticOverflow)?;
            row.operating_load_kw += operating_load_kw;
            row.recharge_energy_kwh += recharge_energy_kwh;
            return Ok(());
        }

        self.rows.push(DemandAccumulatorRow {
            zone_index,
            time_bin_index,
            active_count: 1,
            operating_load_kw,
            recharge_energy_kwh,
        });

        Ok(())
    }

    fn into_rows(mut self) -> Result<Vec<AggregateDemandRow>, PopmathError> {
        self.rows.sort_by(|left, right| {
            (left.zone_index, left.time_bin_index).cmp(&(
                right.zone_index,
                right.time_bin_index,
            ))
        });

        self.rows
            .into_iter()
            .map(|row| {
                Ok(AggregateDemandRow {
                    zone_index: row.zone_index,
                    time_bin_index: row.time_bin_index,
                    active_synthetic_count: PopulationCount::new(row.active_count)?,
                    operating_load_kw: NonNegativeF64::new(row.operating_load_kw)?,
                    recharge_energy_kwh: EnergyKwh::new(
                        NonNegativeF64::new(row.recharge_energy_kwh)?,
                    ),
                })
            })
            .collect()
    }
}
