#![forbid(unsafe_code)]

use num_bigint::BigUint;
use num_traits::Zero;
use serde::{Deserialize, Serialize};
use std::fmt::{Display, Formatter};
use std::str::FromStr;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AssetCode {
    Protein,
    Blood,
    Sugar,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CanonicalQuantity {
    pub asset_code: AssetCode,
    pub scale: u32,
    pub width: usize,
    pub digits: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QuantityError {
    EmptyDigits,
    NonAsciiDigit,
    WidthTooSmall,
    LeadingZeroNotAllowed,
    InvalidWidth,
    ParseFailure,
}

impl Display for QuantityError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmptyDigits => formatter.write_str("quantity digits must not be empty"),
            Self::NonAsciiDigit => formatter.write_str("quantity must contain ASCII digits only"),
            Self::WidthTooSmall => formatter.write_str("quantity does not fit the requested width"),
            Self::LeadingZeroNotAllowed => {
                formatter.write_str("un-padded input must not contain leading zeroes")
            }
            Self::InvalidWidth => formatter.write_str("quantity width must be greater than zero"),
            Self::ParseFailure => formatter.write_str("quantity could not be parsed as an integer"),
        }
    }
}

impl std::error::Error for QuantityError {}

impl CanonicalQuantity {
    pub fn from_unpadded_decimal(
        asset_code: AssetCode,
        scale: u32,
        width: usize,
        input: &str,
    ) -> Result<Self, QuantityError> {
        if width == 0 {
            return Err(QuantityError::InvalidWidth);
        }

        validate_unpadded_decimal(input)?;

        let value = BigUint::from_str(input).map_err(|_| QuantityError::ParseFailure)?;
        let digits = value.to_str_radix(10);

        if digits.len() > width {
            return Err(QuantityError::WidthTooSmall);
        }

        Ok(Self {
            asset_code,
            scale,
            width,
            digits: format!("{digits:0>width$}"),
        })
    }

    pub fn from_canonical_decimal(
        asset_code: AssetCode,
        scale: u32,
        width: usize,
        digits: String,
    ) -> Result<Self, QuantityError> {
        if width == 0 {
            return Err(QuantityError::InvalidWidth);
        }

        if digits.len() != width {
            return Err(QuantityError::WidthTooSmall);
        }

        if digits.is_empty() {
            return Err(QuantityError::EmptyDigits);
        }

        if !digits.bytes().all(|byte| byte.is_ascii_digit()) {
            return Err(QuantityError::NonAsciiDigit);
        }

        Ok(Self {
            asset_code,
            scale,
            width,
            digits,
        })
    }

    pub fn minor_units(&self) -> Result<BigUint, QuantityError> {
        BigUint::from_str(&self.digits).map_err(|_| QuantityError::ParseFailure)
    }

    pub fn is_zero(&self) -> Result<bool, QuantityError> {
        Ok(self.minor_units()?.is_zero())
    }
}

fn validate_unpadded_decimal(input: &str) -> Result<(), QuantityError> {
    if input.is_empty() {
        return Err(QuantityError::EmptyDigits);
    }

    if !input.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(QuantityError::NonAsciiDigit);
    }

    if input.len() > 1 && input.starts_with('0') {
        return Err(QuantityError::LeadingZeroNotAllowed);
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GasSchedule {
    pub protein_weight: BigUint,
    pub blood_weight: BigUint,
    pub sugar_weight: BigUint,
    pub verification_gas: BigUint,
    pub storage_gas: BigUint,
}

impl GasSchedule {
    pub fn calculate(
        &self,
        protein: &CanonicalQuantity,
        blood: &CanonicalQuantity,
        sugar: &CanonicalQuantity,
    ) -> Result<BigUint, QuantityError> {
        let p = protein.minor_units()?;
        let b = blood.minor_units()?;
        let s = sugar.minor_units()?;

        Ok(
            self.protein_weight.clone() * p
                + self.blood_weight.clone() * b
                + self.sugar_weight.clone() * s
                + self.verification_gas.clone()
                + self.storage_gas.clone(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serializes_an_arbitrary_precision_quantity_at_fixed_width() {
        let quantity = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Protein,
            6,
            18,
            "85000",
        )
        .expect("valid arbitrary-precision input");

        assert_eq!(quantity.digits, "000000000000085000");
        assert_eq!(
            quantity.minor_units().expect("valid canonical value"),
            BigUint::from(85_000_u32)
        );
    }

    #[test]
    fn rejects_noncanonical_unpadded_values() {
        let result = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Sugar,
            6,
            18,
            "000085000",
        );

        assert_eq!(result, Err(QuantityError::LeadingZeroNotAllowed));
    }

    #[test]
    fn supports_values_beyond_u128() {
        let input = "999999999999999999999999999999999999999999999999";
        let quantity = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Blood,
            0,
            60,
            input,
        )
        .expect("arbitrary precision amount");

        assert_eq!(quantity.digits.len(), 60);
        assert_eq!(
            quantity.minor_units().expect("parse canonical value").to_str_radix(10),
            input
        );
    }

    #[test]
    fn calculates_integer_gas_without_floating_point() {
        let protein = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Protein,
            0,
            18,
            "2",
        )
        .expect("valid amount");

        let blood = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Blood,
            0,
            18,
            "3",
        )
        .expect("valid amount");

        let sugar = CanonicalQuantity::from_unpadded_decimal(
            AssetCode::Sugar,
            0,
            18,
            "4",
        )
        .expect("valid amount");

        let gas = GasSchedule {
            protein_weight: BigUint::from(3_000_u32),
            blood_weight: BigUint::from(5_000_u32),
            sugar_weight: BigUint::from(2_000_u32),
            verification_gas: BigUint::from(100_u32),
            storage_gas: BigUint::from(50_u32),
        }
        .calculate(&protein, &blood, &sugar)
        .expect("gas calculation");

        assert_eq!(gas, BigUint::from(29_150_u32));
    }
}
