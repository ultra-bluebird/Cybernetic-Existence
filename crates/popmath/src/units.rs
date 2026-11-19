use crate::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};

macro_rules! non_negative_quantity {
    ($name:ident, $documentation:literal) => {
        #[doc = $documentation]
        #[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
        pub struct $name(NonNegativeF64);

        impl $name {
            #[doc = "Creates a validated quantity."]
            pub fn new(value: f64) -> PopmathResult<Self> {
                NonNegativeF64::new(value, stringify!($name)).map(Self)
            }

            #[doc = "Returns the quantity in its canonical unit."]
            #[must_use]
            pub const fn get(self) -> f64 {
                self.0.get()
            }
        }
    };
}

non_negative_quantity!(MassKg, "Mass in kilograms.");
non_negative_quantity!(VolumeM3, "Volume in cubic meters.");
non_negative_quantity!(
    FlowRateM3PerSecond,
    "Volumetric flow rate in cubic meters per second."
);
non_negative_quantity!(DistanceM, "Distance in meters.");
non_negative_quantity!(DurationSeconds, "Duration in seconds.");
non_negative_quantity!(PowerKw, "Power in kilowatts.");
non_negative_quantity!(EnergyKwh, "Energy in kilowatt-hours.");
non_negative_quantity!(EmissionsKgCo2e, "Emissions in kilograms carbon-dioxide-equivalent.");
non_negative_quantity!(PopulationWeight, "Non-negative aggregate population weight.");

/// A non-negative aggregate population count.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct PopulationCount(u64);

impl PopulationCount {
    /// Creates an aggregate population count.
    #[must_use]
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    /// Returns the count.
    #[must_use]
    pub const fn get(self) -> u64 {
        self.0
    }
}

/// A ratio bounded in the inclusive interval from zero to one.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Efficiency(UnitInterval);

impl Efficiency {
    /// Creates an efficiency value.
    pub fn new(value: f64) -> PopmathResult<Self> {
        UnitInterval::new(value, "Efficiency").map(Self)
    }

    /// Returns the efficiency.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0.get()
    }
}

/// An ISO-style three-letter currency code.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct CurrencyCode([u8; 3]);

impl CurrencyCode {
    /// Creates a normalized upper-case alphabetic currency code.
    pub fn new(value: &str) -> PopmathResult<Self> {
        let bytes = value.as_bytes();
        if bytes.len() != 3 || !bytes.iter().all(u8::is_ascii_alphabetic) {
            return Err(PopmathError::InvalidScenario {
                field: "currency_code",
            });
        }

        let mut normalized = [0_u8; 3];
        for (index, byte) in bytes.iter().enumerate() {
            normalized[index] = byte.to_ascii_uppercase();
        }

        Ok(Self(normalized))
    }

    /// Returns the code as an ASCII string slice.
    #[must_use]
    pub fn as_str(&self) -> &str {
        core::str::from_utf8(&self.0).unwrap_or("UNK")
    }
}

/// Currency in integer minor units.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct CurrencyAmount {
    minor_units: i128,
    currency: CurrencyCode,
}

impl CurrencyAmount {
    /// Creates an amount in integer minor units.
    #[must_use]
    pub const fn new(minor_units: i128, currency: CurrencyCode) -> Self {
        Self {
            minor_units,
            currency,
        }
    }

    /// Returns the signed amount in minor units.
    #[must_use]
    pub const fn minor_units(self) -> i128 {
        self.minor_units
    }

    /// Returns the currency code.
    #[must_use]
    pub const fn currency(self) -> CurrencyCode {
        self.currency
    }

    /// Adds two amounts with matching currencies.
    pub fn checked_add(self, other: Self) -> PopmathResult<Self> {
        if self.currency != other.currency {
            return Err(PopmathError::CurrencyMismatch);
        }

        let minor_units =
            self.minor_units
                .checked_add(other.minor_units)
                .ok_or(PopmathError::NumericalInstability {
                    component: "currency_addition",
                })?;

        Ok(Self::new(minor_units, self.currency))
    }
}

/// Converts gallons to cubic meters using the declared U.S. gallon convention.
pub fn us_gallons_to_volume_m3(gallons: f64) -> PopmathResult<VolumeM3> {
    const CUBIC_METERS_PER_US_GALLON: f64 = 0.003_785_411_784;
    VolumeM3::new(gallons * CUBIC_METERS_PER_US_GALLON)
}

/// Converts kilowatt-hours to joules.
pub fn kilowatt_hours_to_joules(energy: EnergyKwh) -> f64 {
    energy.get() * 3_600_000.0
}

/// Converts power and duration to energy.
pub fn power_duration_to_energy_kwh(
    power: PowerKw,
    duration: DurationSeconds,
) -> PopmathResult<EnergyKwh> {
    EnergyKwh::new(power.get() * duration.get() / 3_600.0)
}

/// Converts volumetric flow and duration to volume.
pub fn flow_duration_to_volume_m3(
    flow: FlowRateM3PerSecond,
    duration: DurationSeconds,
) -> PopmathResult<VolumeM3> {
    VolumeM3::new(flow.get() * duration.get())
}

/// Calculates hydraulic power in kilowatts.
pub fn hydraulic_power_kw(
    density_kg_per_m3: PositiveF64,
    gravitational_acceleration_m_per_s2: PositiveF64,
    flow: FlowRateM3PerSecond,
    head_m: PositiveF64,
) -> PopmathResult<PowerKw> {
    let watts = density_kg_per_m3.get()
        * gravitational_acceleration_m_per_s2.get()
        * flow.get()
        * head_m.get();

    PowerKw::new(watts / 1_000.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flow_and_duration_produce_volume() {
        let flow = FlowRateM3PerSecond::new(2.0).expect("valid flow");
        let duration = DurationSeconds::new(30.0).expect("valid duration");
        let volume = flow_duration_to_volume_m3(flow, duration).expect("valid volume");

        assert_eq!(volume.get(), 60.0);
    }

    #[test]
    fn currency_rejects_mismatch() {
        let usd = CurrencyCode::new("usd").expect("valid code");
        let eur = CurrencyCode::new("eur").expect("valid code");
        let result =
            CurrencyAmount::new(100, usd).checked_add(CurrencyAmount::new(100, eur));

        assert_eq!(result, Err(PopmathError::CurrencyMismatch));
    }

    #[test]
    fn us_gallon_conversion_is_explicit() {
        let volume = us_gallons_to_volume_m3(1.0).expect("valid gallon conversion");
        assert!((volume.get() - 0.003_785_411_784).abs() < f64::EPSILON);
    }
}
