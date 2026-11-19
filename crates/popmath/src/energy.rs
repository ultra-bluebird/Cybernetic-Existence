use alloc::vec::Vec;

use crate::battery_degradation::{
    calculate_battery_degradation, BatteryDegradationInput, BatteryDegradationResult,
};
use crate::bounds::{NonNegativeF64, Probability, UnitInterval};
use crate::continuity::{
    assess_continuity_expression, CapabilityExpression, CapabilityKind, CapabilityRequirement,
    CapabilityWindow, ContinuityAssessment, EvidenceStatus,
};
use crate::error::{PopmathError, PopmathResult};
use crate::time::{TimeWindow, UtcTimestamp};
use crate::units::{Efficiency, EnergyKwh};

const SECONDS_PER_HOUR: f64 = 3_600.0;
const PROBABILITY_TOLERANCE: f64 = 1.0e-12;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DurationSeconds(NonNegativeF64);

impl DurationSeconds {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PowerKw(NonNegativeF64);

impl PowerKw {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct VoltageVolts(NonNegativeF64);

impl VoltageVolts {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CurrentAmperes(NonNegativeF64);

impl CurrentAmperes {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FrequencyHertz(NonNegativeF64);

impl FrequencyHertz {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResistanceOhms(NonNegativeF64);

impl ResistanceOhms {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ChargeCoulombs(NonNegativeF64);

impl ChargeCoulombs {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PowerWatts(NonNegativeF64);

impl PowerWatts {
    pub fn new(value: f64) -> PopmathResult<Self> {
        Ok(Self(NonNegativeF64::new(value)?))
    }

    pub fn get(self) -> f64 {
        self.0.value()
    }

    pub fn as_non_negative(self) -> NonNegativeF64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EnergyStorageDegradationInput {
    pub degradation: BatteryDegradationInput,
    pub usable_depth_of_discharge: UnitInterval,
    pub discharge_efficiency: Efficiency,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ConservativeStorageCapacity {
    pub degradation: BatteryDegradationResult,
    pub usable_energy_kwh: EnergyKwh,
}

pub fn calculate_conservative_storage_capacity(
    input: EnergyStorageDegradationInput,
) -> PopmathResult<ConservativeStorageCapacity> {
    if input.usable_depth_of_discharge.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "usable depth of discharge must be greater than zero",
        ));
    }

    if input.discharge_efficiency.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "discharge efficiency must be greater than zero",
        ));
    }

    let degradation = calculate_battery_degradation(input.degradation)?;

    let usable_energy_kwh = degradation.available_capacity_kwh.get()
        * input.usable_depth_of_discharge.value()
        * input.discharge_efficiency.get();

    Ok(ConservativeStorageCapacity {
        degradation,
        usable_energy_kwh: EnergyKwh::new(usable_energy_kwh)?,
    })
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TriangularOutageDistribution {
    pub minimum_duration: DurationSeconds,
    pub mode_duration: DurationSeconds,
    pub maximum_duration: DurationSeconds,
}

impl TriangularOutageDistribution {
    pub fn new(
        minimum_duration: DurationSeconds,
        mode_duration: DurationSeconds,
        maximum_duration: DurationSeconds,
    ) -> PopmathResult<Self> {
        let minimum = minimum_duration.get();
        let mode = mode_duration.get();
        let maximum = maximum_duration.get();

        if minimum > mode || mode > maximum || minimum >= maximum {
            return Err(PopmathError::InvalidInput(
                "triangular outage duration requires minimum <= mode <= maximum and minimum < maximum",
            ));
        }

        Ok(Self {
            minimum_duration,
            mode_duration,
            maximum_duration,
        })
    }

    pub fn expected_duration(self) -> PopmathResult<DurationSeconds> {
        DurationSeconds::new(
            (self.minimum_duration.get()
                + self.mode_duration.get()
                + self.maximum_duration.get())
                / 3.0,
        )
    }

    pub fn probability_at_most(
        self,
        threshold: DurationSeconds,
    ) -> PopmathResult<Probability> {
        let minimum = self.minimum_duration.get();
        let mode = self.mode_duration.get();
        let maximum = self.maximum_duration.get();
        let threshold_value = threshold.get();

        let probability = if threshold_value <= minimum {
            0.0
        } else if threshold_value < mode {
            let numerator = (threshold_value - minimum).powi(2);
            let denominator = (maximum - minimum) * (mode - minimum);
            numerator / denominator
        } else if threshold_value < maximum {
            let numerator = (maximum - threshold_value).powi(2);
            let denominator = (maximum - minimum) * (maximum - mode);
            1.0 - numerator / denominator
        } else {
            1.0
        };

        Probability::new(clamp_probability(probability))
    }

    pub fn worst_case_unmet_duration(
        self,
        support_duration: DurationSeconds,
    ) -> PopmathResult<DurationSeconds> {
        DurationSeconds::new(
            (self.maximum_duration.get() - support_duration.get()).max(0.0),
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CriticalLoadContinuityInput {
    pub stored_energy: EnergyKwh,
    pub discharge_efficiency: Efficiency,
    pub critical_load: PowerKw,
    pub outage_distribution: TriangularOutageDistribution,
}

impl CriticalLoadContinuityInput {
    pub fn support_duration(self) -> PopmathResult<DurationSeconds> {
        if self.critical_load.get() <= 0.0 {
            return Err(PopmathError::InvalidInput(
                "critical load must be greater than zero",
            ));
        }

        if self.discharge_efficiency.get() <= 0.0 {
            return Err(PopmathError::InvalidInput(
                "discharge efficiency must be greater than zero",
            ));
        }

        let deliverable_energy_kwh =
            self.stored_energy.get() * self.discharge_efficiency.get();

        DurationSeconds::new(
            deliverable_energy_kwh / self.critical_load.get() * SECONDS_PER_HOUR,
        )
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct CriticalLoadContinuityResult {
    pub support_duration: DurationSeconds,
    pub expected_outage_duration: DurationSeconds,
    pub probability_outage_is_supported: Probability,
    pub worst_case_unmet_duration: DurationSeconds,
    pub continuity: ContinuityAssessment,
}

pub fn calculate_critical_load_continuity(
    input: CriticalLoadContinuityInput,
    requested_window: TimeWindow,
    evidence: EvidenceStatus,
) -> PopmathResult<CriticalLoadContinuityResult> {
    let support_duration = input.support_duration()?;
    let expected_outage_duration = input.outage_distribution.expected_duration()?;
    let probability_outage_is_supported =
        input.outage_distribution.probability_at_most(support_duration)?;
    let worst_case_unmet_duration =
        input.outage_distribution.worst_case_unmet_duration(support_duration)?;

    let available_end = add_duration_to_timestamp(
        requested_window.start(),
        support_duration,
        requested_window.end(),
    )?;

    let available_window = TimeWindow::new(requested_window.start(), available_end)?;

    let continuity_expression =
        CapabilityExpression::requirement(CapabilityRequirement::new(
            CapabilityKind::ContinuousPower,
            UnitInterval::new(1.0)?,
            NonNegativeF64::new(0.0)?,
            evidence,
        ));

    let continuity = assess_continuity_expression(
        requested_window,
        &continuity_expression,
        &[CapabilityWindow::new(
            CapabilityKind::ContinuousPower,
            available_window,
            evidence,
            true,
        )],
    )?;

    Ok(CriticalLoadContinuityResult {
        support_duration,
        expected_outage_duration,
        probability_outage_is_supported,
        worst_case_unmet_duration,
        continuity,
    })
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PoEConverterInput {
    pub input_voltage: VoltageVolts,
    pub output_voltage: VoltageVolts,
    pub output_current: CurrentAmperes,
    pub switching_frequency: FrequencyHertz,
    pub equivalent_conduction_resistance: ResistanceOhms,
    pub switching_rise_time: DurationSeconds,
    pub switching_fall_time: DurationSeconds,
    pub gate_drive_voltage: VoltageVolts,
    pub total_gate_charge: ChargeCoulombs,
    pub quiescent_power: PowerWatts,
    pub reference_core_loss: PowerWatts,
    pub reference_frequency: FrequencyHertz,
    pub core_loss_frequency_exponent: NonNegativeF64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PoEConverterLossResult {
    pub output_power: PowerWatts,
    pub conduction_loss: PowerWatts,
    pub switching_loss: PowerWatts,
    pub gate_drive_loss: PowerWatts,
    pub magnetic_loss: PowerWatts,
    pub quiescent_loss: PowerWatts,
    pub total_loss: PowerWatts,
    pub input_power: PowerWatts,
    pub efficiency: Efficiency,
}

pub fn calculate_poe_converter_losses(
    input: PoEConverterInput,
) -> PopmathResult<PoEConverterLossResult> {
    if input.input_voltage.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "input voltage must be greater than zero",
        ));
    }

    if input.output_voltage.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "output voltage must be greater than zero",
        ));
    }

    if input.output_current.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "output current must be greater than zero",
        ));
    }

    if input.switching_frequency.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "switching frequency must be greater than zero",
        ));
    }

    if input.reference_frequency.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "reference frequency must be greater than zero",
        ));
    }

    let output_power = input.output_voltage.get() * input.output_current.get();

    let conduction_loss =
        input.output_current.get().powi(2) * input.equivalent_conduction_resistance.get();

    let switching_loss = 0.5
        * input.input_voltage.get()
        * input.output_current.get()
        * (input.switching_rise_time.get() + input.switching_fall_time.get())
        * input.switching_frequency.get();

    let gate_drive_loss = input.gate_drive_voltage.get()
        * input.total_gate_charge.get()
        * input.switching_frequency.get();

    let frequency_ratio = input.switching_frequency.get() / input.reference_frequency.get();

    let magnetic_loss = input.reference_core_loss.get()
        * frequency_ratio.powf(input.core_loss_frequency_exponent.value());

    let total_loss = conduction_loss
        + switching_loss
        + gate_drive_loss
        + magnetic_loss
        + input.quiescent_power.get();

    let input_power = output_power + total_loss;

    if input_power <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "converter input power must be greater than zero",
        ));
    }

    Ok(PoEConverterLossResult {
        output_power: PowerWatts::new(output_power)?,
        conduction_loss: PowerWatts::new(conduction_loss)?,
        switching_loss: PowerWatts::new(switching_loss)?,
        gate_drive_loss: PowerWatts::new(gate_drive_loss)?,
        magnetic_loss: PowerWatts::new(magnetic_loss)?,
        quiescent_loss: input.quiescent_power,
        total_loss: PowerWatts::new(total_loss)?,
        input_power: PowerWatts::new(input_power)?,
        efficiency: Efficiency::new(output_power / input_power)?,
    })
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ConverterEfficiencyPoint {
    pub output_current: CurrentAmperes,
    pub efficiency: Efficiency,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ConverterEfficiencyCurve {
    pub input_voltage: VoltageVolts,
    pub output_voltage: VoltageVolts,
    pub switching_frequency: FrequencyHertz,
    pub points: Vec<ConverterEfficiencyPoint>,
}

pub fn build_converter_efficiency_curve(
    base_input: PoEConverterInput,
    output_currents: &[CurrentAmperes],
) -> PopmathResult<ConverterEfficiencyCurve> {
    if output_currents.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one output-current sample is required",
        ));
    }

    let mut points = Vec::with_capacity(output_currents.len());

    for output_current in output_currents {
        let result = calculate_poe_converter_losses(PoEConverterInput {
            output_current: *output_current,
            ..base_input
        })?;

        points.push(ConverterEfficiencyPoint {
            output_current: *output_current,
            efficiency: result.efficiency,
        });
    }

    points.sort_by(|left, right| {
        left.output_current
            .get()
            .total_cmp(&right.output_current.get())
    });

    Ok(ConverterEfficiencyCurve {
        input_voltage: base_input.input_voltage,
        output_voltage: base_input.output_voltage,
        switching_frequency: base_input.switching_frequency,
        points,
    })
}

pub fn calculate_converter_input_energy(
    output_energy: EnergyKwh,
    efficiency: Efficiency,
) -> PopmathResult<EnergyKwh> {
    if efficiency.get() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "converter efficiency must be greater than zero",
        ));
    }

    EnergyKwh::new(output_energy.get() / efficiency.get())
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EnergyStorageInput {
    pub starting_energy: EnergyKwh,
    pub capacity: EnergyKwh,
    pub charging_energy: EnergyKwh,
    pub discharge_demand: EnergyKwh,
    pub charge_efficiency: Efficiency,
    pub discharge_efficiency: Efficiency,
    pub degradation_input: Option<EnergyStorageDegradationInput>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EnergyStorageResult {
    pub effective_capacity: EnergyKwh,
    pub ending_energy: EnergyKwh,
    pub unmet_demand: EnergyKwh,
    pub curtailed_charge: EnergyKwh,
    pub served_demand: EnergyKwh,
    pub degradation: Option<BatteryDegradationResult>,
}

pub fn calculate_energy_storage(
    input: EnergyStorageInput,
) -> PopmathResult<EnergyStorageResult> {
    if input.charge_efficiency.get() < 0.0 || input.charge_efficiency.get() > 1.0 {
        return Err(PopmathError::InvalidInput(
            "charge efficiency must be inside the unit interval",
        ));
    }

    if input.discharge_efficiency.get() <= 0.0 || input.discharge_efficiency.get() > 1.0 {
        return Err(PopmathError::InvalidInput(
            "discharge efficiency must be greater than zero and inside the unit interval",
        ));
    }

    let conservative_capacity = match input.degradation_input {
        Some(degradation_input) => Some(calculate_conservative_storage_capacity(
            degradation_input,
        )?),
        None => None,
    };

    let effective_capacity = conservative_capacity
        .map(|capacity| input.capacity.get().min(capacity.usable_energy_kwh.get()))
        .unwrap_or_else(|| input.capacity.get());

    if input.starting_energy.get() > effective_capacity {
        return Err(PopmathError::InvalidInput(
            "starting energy must not exceed effective storage capacity",
        ));
    }

    let charge_after_efficiency = input.charging_energy.get() * input.charge_efficiency.get();
    let unconstrained_stored_energy = input.starting_energy.get() + charge_after_efficiency;
    let stored_after_charge = unconstrained_stored_energy.min(effective_capacity);
    let curtailed_charge = (unconstrained_stored_energy - effective_capacity).max(0.0);

    let delivered_capacity = stored_after_charge * input.discharge_efficiency.get();
    let served_demand = input.discharge_demand.get().min(delivered_capacity);
    let unmet_demand = input.discharge_demand.get() - served_demand;
    let ending_energy = stored_after_charge - (served_demand / input.discharge_efficiency.get());

    Ok(EnergyStorageResult {
        effective_capacity: EnergyKwh::new(effective_capacity)?,
        ending_energy: EnergyKwh::new(ending_energy.max(0.0))?,
        unmet_demand: EnergyKwh::new(unmet_demand)?,
        curtailed_charge: EnergyKwh::new(curtailed_charge)?,
        served_demand: EnergyKwh::new(served_demand)?,
        degradation: conservative_capacity.map(|capacity| capacity.degradation),
    })
}

fn add_duration_to_timestamp(
    start: UtcTimestamp,
    duration: DurationSeconds,
    upper_bound: UtcTimestamp,
) -> PopmathResult<UtcTimestamp> {
    let duration_seconds = duration.get();

    if duration_seconds >= i64::MAX as f64 {
        return Ok(upper_bound);
    }

    let integral_seconds = duration_seconds.floor() as i64;
    let candidate_seconds = start.seconds_since_epoch().saturating_add(integral_seconds);
    let candidate = UtcTimestamp::new(candidate_seconds)?;

    Ok(candidate.min(upper_bound))
}

fn clamp_probability(value: f64) -> f64 {
    if value <= PROBABILITY_TOLERANCE {
        0.0
    } else if value >= 1.0 - PROBABILITY_TOLERANCE {
        1.0
    } else {
        value.clamp(0.0, 1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn timestamp(seconds_since_epoch: i64) -> UtcTimestamp {
        UtcTimestamp::new(seconds_since_epoch).expect("valid timestamp")
    }

    fn time_window(start_seconds: i64, end_seconds: i64) -> TimeWindow {
        TimeWindow::new(timestamp(start_seconds), timestamp(end_seconds))
            .expect("valid time window")
    }

    fn duration(seconds: f64) -> DurationSeconds {
        DurationSeconds::new(seconds).expect("valid duration")
    }

    fn power(kw: f64) -> PowerKw {
        PowerKw::new(kw).expect("valid power")
    }

    fn converter_input(output_current: f64) -> PoEConverterInput {
        PoEConverterInput {
            input_voltage: VoltageVolts::new(48.0).expect("valid input voltage"),
            output_voltage: VoltageVolts::new(12.0).expect("valid output voltage"),
            output_current: CurrentAmperes::new(output_current)
                .expect("valid output current"),
            switching_frequency: FrequencyHertz::new(300_000.0)
                .expect("valid switching frequency"),
            equivalent_conduction_resistance: ResistanceOhms::new(0.08)
                .expect("valid resistance"),
            switching_rise_time: DurationSeconds::new(20.0e-9)
                .expect("valid rise time"),
            switching_fall_time: DurationSeconds::new(20.0e-9)
                .expect("valid fall time"),
            gate_drive_voltage: VoltageVolts::new(5.0)
                .expect("valid gate drive voltage"),
            total_gate_charge: ChargeCoulombs::new(35.0e-9)
                .expect("valid gate charge"),
            quiescent_power: PowerWatts::new(0.05)
                .expect("valid quiescent power"),
            reference_core_loss: PowerWatts::new(0.12)
                .expect("valid reference core loss"),
            reference_frequency: FrequencyHertz::new(300_000.0)
                .expect("valid reference frequency"),
            core_loss_frequency_exponent: NonNegativeF64::new(1.3)
                .expect("valid frequency exponent"),
        }
    }

    fn storage_input(
        starting_energy: f64,
        capacity: f64,
        charging_energy: f64,
        discharge_demand: f64,
    ) -> EnergyStorageInput {
        EnergyStorageInput {
            starting_energy: EnergyKwh::new(starting_energy).expect("valid energy"),
            capacity: EnergyKwh::new(capacity).expect("valid energy"),
            charging_energy: EnergyKwh::new(charging_energy).expect("valid energy"),
            discharge_demand: EnergyKwh::new(discharge_demand).expect("valid energy"),
            charge_efficiency: Efficiency::new(0.9).expect("valid efficiency"),
            discharge_efficiency: Efficiency::new(0.9).expect("valid efficiency"),
            degradation_input: None,
        }
    }

    #[test]
    fn energy_storage_reports_unmet_demand() {
        let result = calculate_energy_storage(storage_input(50.0, 100.0, 20.0, 80.0))
            .expect("valid calculation");

        assert_eq!(result.effective_capacity.get(), 100.0);
        assert_eq!(result.served_demand.get(), 61.2);
        assert_eq!(result.unmet_demand.get(), 18.8);
        assert_eq!(result.ending_energy.get(), 0.0);
        assert_eq!(result.curtailed_charge.get(), 0.0);
    }

    #[test]
    fn energy_storage_reports_curtailed_charge() {
        let result = calculate_energy_storage(storage_input(95.0, 100.0, 20.0, 0.0))
            .expect("valid calculation");

        assert_eq!(result.effective_capacity.get(), 100.0);
        assert_eq!(result.ending_energy.get(), 100.0);
        assert_eq!(result.curtailed_charge.get(), 13.0);
        assert_eq!(result.served_demand.get(), 0.0);
        assert_eq!(result.unmet_demand.get(), 0.0);
    }

    #[test]
    fn triangular_distribution_returns_expected_duration() {
        let distribution = TriangularOutageDistribution::new(
            duration(600.0),
            duration(1_800.0),
            duration(3_600.0),
        )
        .expect("valid distribution");

        assert_eq!(
            distribution
                .expected_duration()
                .expect("expected duration")
                .get(),
            2_000.0
        );
    }

    #[test]
    fn triangular_distribution_returns_probability_at_mode() {
        let distribution = TriangularOutageDistribution::new(
            duration(600.0),
            duration(1_800.0),
            duration(3_600.0),
        )
        .expect("valid distribution");

        let probability = distribution
            .probability_at_most(duration(1_800.0))
            .expect("probability");

        assert_eq!(probability.value(), 0.4);
    }

    #[test]
    fn critical_load_support_duration_uses_energy_and_efficiency() {
        let distribution = TriangularOutageDistribution::new(
            duration(600.0),
            duration(1_800.0),
            duration(3_600.0),
        )
        .expect("valid distribution");

        let result = calculate_critical_load_continuity(
            CriticalLoadContinuityInput {
                stored_energy: EnergyKwh::new(2.0).expect("valid energy"),
                discharge_efficiency: Efficiency::new(0.9)
                    .expect("valid efficiency"),
                critical_load: power(1.0),
                outage_distribution: distribution,
            },
            time_window(0, 7_200),
            EvidenceStatus::Verified,
        )
        .expect("critical-load continuity");

        assert_eq!(result.support_duration.get(), 6_480.0);
        assert_eq!(result.expected_outage_duration.get(), 2_000.0);
        assert_eq!(result.probability_outage_is_supported.value(), 1.0);
        assert_eq!(result.worst_case_unmet_duration.get(), 0.0);
    }

    #[test]
    fn critical_load_reports_worst_case_unmet_duration() {
        let distribution = TriangularOutageDistribution::new(
            duration(1_800.0),
            duration(3_600.0),
            duration(7_200.0),
        )
        .expect("valid distribution");

        let result = calculate_critical_load_continuity(
            CriticalLoadContinuityInput {
                stored_energy: EnergyKwh::new(0.5).expect("valid energy"),
                discharge_efficiency: Efficiency::new(1.0)
                    .expect("valid efficiency"),
                critical_load: power(1.0),
                outage_distribution: distribution,
            },
            time_window(0, 7_200),
            EvidenceStatus::Verified,
        )
        .expect("critical-load continuity");

        assert_eq!(result.support_duration.get(), 1_800.0);
        assert_eq!(result.worst_case_unmet_duration.get(), 5_400.0);
    }

    #[test]
    fn zero_critical_load_is_rejected() {
        let distribution = TriangularOutageDistribution::new(
            duration(0.0),
            duration(60.0),
            duration(120.0),
        )
        .expect("valid distribution");

        let result = CriticalLoadContinuityInput {
            stored_energy: EnergyKwh::new(1.0).expect("valid energy"),
            discharge_efficiency: Efficiency::new(1.0).expect("valid efficiency"),
            critical_load: power(0.0),
            outage_distribution: distribution,
        }
        .support_duration();

        assert!(result.is_err());
    }

    #[test]
    fn starting_energy_above_capacity_is_rejected() {
        let result = calculate_energy_storage(storage_input(101.0, 100.0, 0.0, 0.0));

        assert!(result.is_err());
    }

    #[test]
    fn poe_converter_calculates_positive_losses_and_bounded_efficiency() {
        let result = calculate_poe_converter_losses(converter_input(1.0))
            .expect("valid converter result");

        assert!(result.output_power.get() > 0.0);
        assert!(result.total_loss.get() > 0.0);
        assert!(result.input_power.get() > result.output_power.get());
        assert!(result.efficiency.get() > 0.0);
        assert!(result.efficiency.get() < 1.0);
    }

    #[test]
    fn poe_converter_curve_is_sorted_by_output_current() {
        let curve = build_converter_efficiency_curve(
            converter_input(1.0),
            &[
                CurrentAmperes::new(2.0).expect("valid current"),
                CurrentAmperes::new(0.5).expect("valid current"),
                CurrentAmperes::new(1.0).expect("valid current"),
            ],
        )
        .expect("valid curve");

        assert_eq!(curve.points.len(), 3);
        assert_eq!(curve.points[0].output_current.get(), 0.5);
        assert_eq!(curve.points[1].output_current.get(), 1.0);
        assert_eq!(curve.points[2].output_current.get(), 2.0);
    }

    #[test]
    fn converter_input_energy_exceeds_output_energy_for_non_ideal_efficiency() {
        let input_energy = calculate_converter_input_energy(
            EnergyKwh::new(9.0).expect("valid output energy"),
            Efficiency::new(0.9).expect("valid efficiency"),
        )
        .expect("valid input energy");

        assert_eq!(input_energy.get(), 10.0);
    }

    #[test]
    fn zero_converter_efficiency_is_rejected_for_input_energy() {
        let result = calculate_converter_input_energy(
            EnergyKwh::new(1.0).expect("valid output energy"),
            Efficiency::new(0.0).expect("valid efficiency"),
        );

        assert!(result.is_err());
    }
}
