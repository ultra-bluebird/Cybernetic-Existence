use std::fmt;

const BASIS_POINTS_PER_UNIT: i128 = 10_000;
const WATT_HOURS_PER_KILOWATT_HOUR: i128 = 1_000;
const MILLIMETERS_PER_METER: u64 = 1_000;
const MILLIMETERS_PER_KILOMETER: u64 = 1_000_000;
const MAX_WALKING_DISTANCE_TO_COOLED_ZONE_MILLIMETERS: u64 = 500 * MILLIMETERS_PER_METER;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct UnitInterval(u16);

impl UnitInterval {
    pub const ZERO: Self = Self(0);
    pub const ONE: Self = Self(BASIS_POINTS_PER_UNIT as u16);

    pub fn from_basis_points(basis_points: u16) -> Result<Self, InfrastructureError> {
        if basis_points > BASIS_POINTS_PER_UNIT as u16 {
            return Err(InfrastructureError::InvalidUnitInterval { basis_points });
        }

        Ok(Self(basis_points))
    }

    pub fn from_ratio(
        numerator: u64,
        denominator: u64,
    ) -> Result<Self, InfrastructureError> {
        if denominator == 0 {
            return Err(InfrastructureError::ZeroDenominator);
        }

        if numerator > denominator {
            return Err(InfrastructureError::InvalidRatio {
                numerator,
                denominator,
            });
        }

        let basis_points = numerator
            .checked_mul(BASIS_POINTS_PER_UNIT as u64)
            .ok_or(InfrastructureError::ArithmeticOverflow)?
            / denominator;

        Self::from_basis_points(basis_points as u16)
    }

    pub fn basis_points(self) -> u16 {
        self.0
    }

    pub fn as_f64(self) -> f64 {
        self.0 as f64 / BASIS_POINTS_PER_UNIT as f64
    }

    pub fn minimum(self, other: Self) -> Self {
        Self(self.0.min(other.0))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EvidenceStatus {
    Verified,
    PendingReview,
    Rejected,
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CapabilityRequirement {
    pub capability: String,
    pub minimum_score: UnitInterval,
    pub measured_score: UnitInterval,
    pub evidence_status: EvidenceStatus,
    pub satisfied: bool,
    pub explanation: String,
}

impl CapabilityRequirement {
    pub fn verified(
        capability: impl Into<String>,
        minimum_score: UnitInterval,
        measured_score: UnitInterval,
        explanation: impl Into<String>,
    ) -> Self {
        Self {
            capability: capability.into(),
            minimum_score,
            measured_score,
            evidence_status: EvidenceStatus::Verified,
            satisfied: measured_score >= minimum_score,
            explanation: explanation.into(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MoneyMicros(pub i128);

impl MoneyMicros {
    pub const ZERO: Self = Self(0);

    pub fn checked_add(self, other: Self) -> Result<Self, InfrastructureError> {
        self.0
            .checked_add(other.0)
            .map(Self)
            .ok_or(InfrastructureError::ArithmeticOverflow)
    }

    pub fn checked_sub(self, other: Self) -> Result<Self, InfrastructureError> {
        self.0
            .checked_sub(other.0)
            .map(Self)
            .ok_or(InfrastructureError::ArithmeticOverflow)
    }

    pub fn checked_mul_i128(self, multiplier: i128) -> Result<Self, InfrastructureError> {
        self.0
            .checked_mul(multiplier)
            .map(Self)
            .ok_or(InfrastructureError::ArithmeticOverflow)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResultMetrics {
    pub annual_social_benefit_micros: MoneyMicros,
    pub annual_operating_cost_micros: MoneyMicros,
    pub annual_net_social_benefit_micros: MoneyMicros,
    pub social_return_ratio_basis_points: i64,
    pub social_return_ratio: Option<f64>,
    pub evidence_status: EvidenceStatus,
    pub explanation: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SocialReturnInputs {
    pub annualized_capital_cost_micros: MoneyMicros,
    pub annual_operating_cost_micros: MoneyMicros,
    pub annual_mobility_trip_increase: u64,
    pub social_value_per_added_trip_micros: MoneyMicros,
    pub annual_healthcare_cost_reduction_micros: MoneyMicros,
    pub annual_avoided_discrimination_harm_micros: MoneyMicros,
    pub annual_maintenance_access_benefit_micros: MoneyMicros,
    pub evidence_status: EvidenceStatus,
}

pub fn calculate_annual_social_return(
    inputs: &SocialReturnInputs,
) -> Result<ResultMetrics, InfrastructureError> {
    let mobility_benefit = inputs
        .social_value_per_added_trip_micros
        .checked_mul_i128(inputs.annual_mobility_trip_increase as i128)?;

    let annual_social_benefit = mobility_benefit
        .checked_add(inputs.annual_healthcare_cost_reduction_micros)?
        .checked_add(inputs.annual_avoided_discrimination_harm_micros)?
        .checked_add(inputs.annual_maintenance_access_benefit_micros)?;

    let annual_investment_cost = inputs
        .annualized_capital_cost_micros
        .checked_add(inputs.annual_operating_cost_micros)?;

    if annual_investment_cost.0 <= 0 {
        return Err(InfrastructureError::NonPositiveInvestmentCost {
            investment_cost_micros: annual_investment_cost.0,
        });
    }

    let annual_net_social_benefit = annual_social_benefit.checked_sub(annual_investment_cost)?;

    let social_return_ratio_basis_points = annual_net_social_benefit
        .0
        .checked_mul(BASIS_POINTS_PER_UNIT)
        .ok_or(InfrastructureError::ArithmeticOverflow)?
        .checked_div(annual_investment_cost.0)
        .ok_or(InfrastructureError::ZeroDenominator)?;

    let social_return_ratio = Some(
        social_return_ratio_basis_points as f64 / BASIS_POINTS_PER_UNIT as f64,
    );

    let explanation = format!(
        "Annual social benefit is {} micro-units, annual investment cost is {} micro-units, and annual net social benefit is {} micro-units. The social return ratio equals net social benefit divided by annualized capital plus annual operating cost.",
        annual_social_benefit.0,
        annual_investment_cost.0,
        annual_net_social_benefit.0,
    );

    Ok(ResultMetrics {
        annual_social_benefit_micros: annual_social_benefit,
        annual_operating_cost_micros: inputs.annual_operating_cost_micros,
        annual_net_social_benefit_micros: annual_net_social_benefit,
        social_return_ratio_basis_points: social_return_ratio_basis_points as i64,
        social_return_ratio,
        evidence_status: inputs.evidence_status.clone(),
        explanation,
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CoolingStationEnergyDemand {
    pub cooling_load_watts: u32,
    pub auxiliary_load_watts: u32,
    pub operating_hours_per_day: u16,
    pub operating_days_per_year: u16,
    pub coefficient_of_performance_basis_points: u16,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoolingStationEnergyAssessment {
    pub electrical_power_watts: u32,
    pub daily_energy_watt_hours: u64,
    pub annual_energy_watt_hours: u64,
    pub annual_energy_kilowatt_hours: u64,
}

impl CoolingStationEnergyDemand {
    pub fn assess(self) -> Result<CoolingStationEnergyAssessment, InfrastructureError> {
        if self.cooling_load_watts == 0 {
            return Err(InfrastructureError::InvalidMeasurement {
                field: "cooling_load_watts",
                value: self.cooling_load_watts as u64,
            });
        }

        if self.auxiliary_load_watts == 0 {
            return Err(InfrastructureError::InvalidMeasurement {
                field: "auxiliary_load_watts",
                value: self.auxiliary_load_watts as u64,
            });
        }

        if self.operating_hours_per_day == 0 || self.operating_hours_per_day > 24 {
            return Err(InfrastructureError::InvalidMeasurement {
                field: "operating_hours_per_day",
                value: self.operating_hours_per_day as u64,
            });
        }

        if self.operating_days_per_year == 0 || self.operating_days_per_year > 366 {
            return Err(InfrastructureError::InvalidMeasurement {
                field: "operating_days_per_year",
                value: self.operating_days_per_year as u64,
            });
        }

        if self.coefficient_of_performance_basis_points == 0 {
            return Err(InfrastructureError::InvalidMeasurement {
                field: "coefficient_of_performance_basis_points",
                value: 0,
            });
        }

        let compressor_power_watts = (self.cooling_load_watts as u64)
            .checked_mul(BASIS_POINTS_PER_UNIT as u64)
            .ok_or(InfrastructureError::ArithmeticOverflow)?
            .checked_div(self.coefficient_of_performance_basis_points as u64)
            .ok_or(InfrastructureError::ZeroDenominator)?;

        let electrical_power_watts = compressor_power_watts
            .checked_add(self.auxiliary_load_watts as u64)
            .ok_or(InfrastructureError::ArithmeticOverflow)?;

        let daily_energy_watt_hours = electrical_power_watts
            .checked_mul(self.operating_hours_per_day as u64)
            .ok_or(InfrastructureError::ArithmeticOverflow)?;

        let annual_energy_watt_hours = daily_energy_watt_hours
            .checked_mul(self.operating_days_per_year as u64)
            .ok_or(InfrastructureError::ArithmeticOverflow)?;

        Ok(CoolingStationEnergyAssessment {
            electrical_power_watts: electrical_power_watts as u32,
            daily_energy_watt_hours,
            annual_energy_watt_hours,
            annual_energy_kilowatt_hours: annual_energy_watt_hours
                .checked_div(WATT_HOURS_PER_KILOWATT_HOUR as u64)
                .ok_or(InfrastructureError::ZeroDenominator)?,
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ThermalComfortMeasurements {
    pub ambient_temperature_milli_celsius: i32,
    pub cooled_zone_temperature_milli_celsius: i32,
    pub implant_safe_temperature_milli_celsius: i32,
    pub distance_to_nearest_cooled_zone_millimeters: u64,
    pub maximum_allowed_distance_millimeters: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThermalComfortAssessment {
    pub thermal_temperature_score: UnitInterval,
    pub cooled_zone_proximity_score: UnitInterval,
    pub thermal_comfort_score: UnitInterval,
    pub capability_requirement: CapabilityRequirement,
}

pub fn assess_thermal_comfort(
    measurements: ThermalComfortMeasurements,
    required_score: UnitInterval,
) -> Result<ThermalComfortAssessment, InfrastructureError> {
    if measurements.maximum_allowed_distance_millimeters == 0 {
        return Err(InfrastructureError::InvalidMeasurement {
            field: "maximum_allowed_distance_millimeters",
            value: 0,
        });
    }

    let thermal_temperature_score =
        temperature_safety_score(
            measurements.cooled_zone_temperature_milli_celsius,
            measurements.implant_safe_temperature_milli_celsius,
        );

    let cooled_zone_proximity_score = UnitInterval::from_ratio(
        measurements
            .maximum_allowed_distance_millimeters
            .saturating_sub(measurements.distance_to_nearest_cooled_zone_millimeters),
        measurements.maximum_allowed_distance_millimeters,
    )?;

    let thermal_comfort_score = thermal_temperature_score.minimum(cooled_zone_proximity_score);

    let explanation = format!(
        "Thermal Comfort score is the minimum of cooled-zone thermal safety {:.4} and cooled-zone proximity {:.4}. Ambient temperature is {} milli-degrees Celsius, cooled-zone temperature is {} milli-degrees Celsius, and the implant safety threshold is {} milli-degrees Celsius.",
        thermal_temperature_score.as_f64(),
        cooled_zone_proximity_score.as_f64(),
        measurements.ambient_temperature_milli_celsius,
        measurements.cooled_zone_temperature_milli_celsius,
        measurements.implant_safe_temperature_milli_celsius,
    );

    let capability_requirement = CapabilityRequirement::verified(
        "thermal_comfort_for_heat_sensitive_cybernetics",
        required_score,
        thermal_comfort_score,
        explanation,
    );

    Ok(ThermalComfortAssessment {
        thermal_temperature_score,
        cooled_zone_proximity_score,
        thermal_comfort_score,
        capability_requirement,
    })
}

pub fn cooling_stations_required_per_kilometer(
    maximum_walking_distance_millimeters: u64,
) -> Result<u64, InfrastructureError> {
    if maximum_walking_distance_millimeters == 0 {
        return Err(InfrastructureError::InvalidMeasurement {
            field: "maximum_walking_distance_millimeters",
            value: 0,
        });
    }

    let maximum_station_spacing_millimeters = maximum_walking_distance_millimeters
        .checked_mul(2)
        .ok_or(InfrastructureError::ArithmeticOverflow)?;

    let station_count = ceil_division(
        MILLIMETERS_PER_KILOMETER,
        maximum_station_spacing_millimeters,
    )?;

    Ok(station_count.max(1))
}

pub fn standard_cooling_stations_required_per_kilometer() -> u64 {
    cooling_stations_required_per_kilometer(
        MAX_WALKING_DISTANCE_TO_COOLED_ZONE_MILLIMETERS,
    )
    .expect("the standard maximum walking distance is non-zero")
}

fn temperature_safety_score(
    cooled_zone_temperature_milli_celsius: i32,
    implant_safe_temperature_milli_celsius: i32,
) -> UnitInterval {
    if cooled_zone_temperature_milli_celsius <= implant_safe_temperature_milli_celsius {
        return UnitInterval::ONE;
    }

    UnitInterval::ZERO
}

fn ceil_division(numerator: u64, denominator: u64) -> Result<u64, InfrastructureError> {
    if denominator == 0 {
        return Err(InfrastructureError::ZeroDenominator);
    }

    numerator
        .checked_add(denominator - 1)
        .ok_or(InfrastructureError::ArithmeticOverflow)
        .map(|value| value / denominator)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InfrastructureError {
    ArithmeticOverflow,
    InvalidMeasurement {
        field: &'static str,
        value: u64,
    },
    InvalidRatio {
        numerator: u64,
        denominator: u64,
    },
    InvalidUnitInterval {
        basis_points: u16,
    },
    NonPositiveInvestmentCost {
        investment_cost_micros: i128,
    },
    ZeroDenominator,
}

impl fmt::Display for InfrastructureError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ArithmeticOverflow => write!(formatter, "an arithmetic operation overflowed"),
            Self::InvalidMeasurement { field, value } => {
                write!(formatter, "measurement '{}' is invalid: {}", field, value)
            }
            Self::InvalidRatio {
                numerator,
                denominator,
            } => write!(
                formatter,
                "ratio numerator {} exceeds denominator {}",
                numerator, denominator
            ),
            Self::InvalidUnitInterval { basis_points } => write!(
                formatter,
                "basis-point value {} exceeds the UnitInterval maximum",
                basis_points
            ),
            Self::NonPositiveInvestmentCost {
                investment_cost_micros,
            } => write!(
                formatter,
                "annual investment cost must be positive, found {} micro-units",
                investment_cost_micros
            ),
            Self::ZeroDenominator => write!(formatter, "division denominator must not be zero"),
        }
    }
}

impl std::error::Error for InfrastructureError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn calculates_positive_annual_social_return_ratio() {
        let metrics = calculate_annual_social_return(&SocialReturnInputs {
            annualized_capital_cost_micros: MoneyMicros(120_000_000),
            annual_operating_cost_micros: MoneyMicros(30_000_000),
            annual_mobility_trip_increase: 20_000,
            social_value_per_added_trip_micros: MoneyMicros(4_000),
            annual_healthcare_cost_reduction_micros: MoneyMicros(60_000_000),
            annual_avoided_discrimination_harm_micros: MoneyMicros(35_000_000),
            annual_maintenance_access_benefit_micros: MoneyMicros(15_000_000),
            evidence_status: EvidenceStatus::Verified,
        })
        .unwrap();

        assert_eq!(metrics.annual_social_benefit_micros, MoneyMicros(190_000_000));
        assert_eq!(metrics.annual_net_social_benefit_micros, MoneyMicros(40_000_000));
        assert_eq!(metrics.social_return_ratio_basis_points, 2_666);
        assert_eq!(metrics.evidence_status, EvidenceStatus::Verified);
    }

    #[test]
    fn estimates_energy_for_a_cooling_station() {
        let assessment = CoolingStationEnergyDemand {
            cooling_load_watts: 6_000,
            auxiliary_load_watts: 800,
            operating_hours_per_day: 12,
            operating_days_per_year: 180,
            coefficient_of_performance_basis_points: 30_000,
        }
        .assess()
        .unwrap();

        assert_eq!(assessment.electrical_power_watts, 2_800);
        assert_eq!(assessment.daily_energy_watt_hours, 33_600);
        assert_eq!(assessment.annual_energy_kilowatt_hours, 6_048);
    }

    #[test]
    fn thermal_comfort_fails_when_cooling_zone_is_too_far_away() {
        let assessment = assess_thermal_comfort(
            ThermalComfortMeasurements {
                ambient_temperature_milli_celsius: 42_000,
                cooled_zone_temperature_milli_celsius: 30_000,
                implant_safe_temperature_milli_celsius: 35_000,
                distance_to_nearest_cooled_zone_millimeters: 700_000,
                maximum_allowed_distance_millimeters: 500_000,
            },
            UnitInterval::ONE,
        )
        .unwrap();

        assert_eq!(assessment.thermal_temperature_score, UnitInterval::ONE);
        assert_eq!(assessment.cooled_zone_proximity_score, UnitInterval::ZERO);
        assert_eq!(assessment.thermal_comfort_score, UnitInterval::ZERO);
        assert_eq!(
            assessment.capability_requirement.evidence_status,
            EvidenceStatus::Verified
        );
        assert!(!assessment.capability_requirement.satisfied);
    }

    #[test]
    fn maximum_five_hundred_meter_walk_requires_one_station_per_kilometer() {
        assert_eq!(standard_cooling_stations_required_per_kilometer(), 1);
    }

    #[test]
    fn shorter_maximum_distance_requires_more_cooling_stations() {
        assert_eq!(cooling_stations_required_per_kilometer(250_000).unwrap(), 2);
    }
}
