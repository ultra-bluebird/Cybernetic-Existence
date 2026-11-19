use crate::error::{PopmathError, PopmathResult};

/// A finite floating-point value.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct FiniteF64(f64);

impl FiniteF64 {
    /// Creates a finite value.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        if !value.is_finite() {
            return Err(PopmathError::NonFiniteValue { field });
        }

        Ok(Self(value))
    }

    /// Returns the stored value.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0
    }
}

/// A finite floating-point value greater than or equal to zero.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct NonNegativeF64(f64);

impl NonNegativeF64 {
    /// Creates a finite non-negative value.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        if !value.is_finite() {
            return Err(PopmathError::NonFiniteValue { field });
        }
        if value < 0.0 {
            return Err(PopmathError::NegativeValue { field });
        }

        Ok(Self(value))
    }

    /// Returns the stored value.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0
    }
}

/// A finite floating-point value greater than zero.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct PositiveF64(f64);

impl PositiveF64 {
    /// Creates a finite positive value.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        if !value.is_finite() {
            return Err(PopmathError::NonFiniteValue { field });
        }
        if value < 0.0 {
            return Err(PopmathError::NegativeValue { field });
        }
        if value == 0.0 {
            return Err(PopmathError::ZeroNotAllowed { field });
        }

        Ok(Self(value))
    }

    /// Returns the stored value.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0
    }
}

/// A value in the inclusive interval from zero to one.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct UnitInterval(f64);

impl UnitInterval {
    /// Creates a finite value in the inclusive interval from zero to one.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        if !value.is_finite() {
            return Err(PopmathError::NonFiniteValue { field });
        }
        if !(0.0..=1.0).contains(&value) {
            return Err(PopmathError::OutOfRange {
                field,
                minimum: "0",
                maximum: "1",
            });
        }

        Ok(Self(value))
    }

    /// Returns the stored value.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0
    }
}

/// A probability in the inclusive interval from zero to one.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Probability(UnitInterval);

impl Probability {
    /// Creates a probability.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        UnitInterval::new(value, field).map(Self)
    }

    /// Returns the probability.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0.get()
    }
}

/// A finite, non-negative ratio.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Ratio(NonNegativeF64);

impl Ratio {
    /// Creates a ratio.
    pub fn new(value: f64, field: &'static str) -> PopmathResult<Self> {
        NonNegativeF64::new(value, field).map(Self)
    }

    /// Returns the ratio.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0.get()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unit_interval_rejects_value_above_one() {
        let result = UnitInterval::new(1.01, "coverage");
        assert!(matches!(result, Err(PopmathError::OutOfRange { .. })));
    }

    #[test]
    fn non_negative_rejects_negative_value() {
        let result = NonNegativeF64::new(-0.001, "volume");
        assert!(matches!(result, Err(PopmathError::NegativeValue { .. })));
    }

    #[test]
    fn finite_rejects_nan() {
        let result = FiniteF64::new(f64::NAN, "coefficient");
        assert!(matches!(result, Err(PopmathError::NonFiniteValue { .. })));
    }
}
