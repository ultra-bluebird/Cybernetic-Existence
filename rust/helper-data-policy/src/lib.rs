#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EntropyBudget {
    pub source_min_entropy_bits: f64,
    pub helper_data_leakage_bound_bits: f64,
    pub extracted_key_bits: f64,
    pub statistical_security_bits: f64,
    pub uncertainty_reserve_bits: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EnrollmentPolicy {
    pub maximum_helper_data_records: u32,
    pub requested_helper_data_records: u32,
    pub minimum_residual_entropy_bits: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LeakageAssessment {
    pub residual_entropy_bits: f64,
    pub required_entropy_bits: f64,
    pub accepted: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HelperDataError {
    NonFiniteValue,
    NegativeValue,
    InvalidRecordCount,
}

pub fn assess_enrollment(
    budget: EntropyBudget,
    policy: EnrollmentPolicy,
) -> Result<LeakageAssessment, HelperDataError> {
    validate_non_negative(budget.source_min_entropy_bits)?;
    validate_non_negative(budget.helper_data_leakage_bound_bits)?;
    validate_non_negative(budget.extracted_key_bits)?;
    validate_non_negative(budget.statistical_security_bits)?;
    validate_non_negative(budget.uncertainty_reserve_bits)?;
    validate_non_negative(policy.minimum_residual_entropy_bits)?;

    if policy.requested_helper_data_records == 0
        || policy.maximum_helper_data_records == 0
        || policy.requested_helper_data_records > policy.maximum_helper_data_records
    {
        return Err(HelperDataError::InvalidRecordCount);
    }

    let cumulative_leakage = budget.helper_data_leakage_bound_bits
        * f64::from(policy.requested_helper_data_records);

    let residual_entropy_bits =
        (budget.source_min_entropy_bits - cumulative_leakage).max(0.0);

    let required_entropy_bits = budget.extracted_key_bits
        + 2.0 * budget.statistical_security_bits
        + budget.uncertainty_reserve_bits;

    let accepted = residual_entropy_bits >= required_entropy_bits
        && residual_entropy_bits >= policy.minimum_residual_entropy_bits;

    Ok(LeakageAssessment {
        residual_entropy_bits,
        required_entropy_bits,
        accepted,
    })
}

fn validate_non_negative(value: f64) -> Result<(), HelperDataError> {
    if !value.is_finite() {
        return Err(HelperDataError::NonFiniteValue);
    }

    if value < 0.0 {
        return Err(HelperDataError::NegativeValue);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_when_entropy_budget_exceeds_key_and_security_requirements() {
        let result = assess_enrollment(
            EntropyBudget {
                source_min_entropy_bits: 512.0,
                helper_data_leakage_bound_bits: 64.0,
                extracted_key_bits: 128.0,
                statistical_security_bits: 64.0,
                uncertainty_reserve_bits: 32.0,
            },
            EnrollmentPolicy {
                maximum_helper_data_records: 2,
                requested_helper_data_records: 1,
                minimum_residual_entropy_bits: 256.0,
            },
        )
        .expect("valid assessment");

        assert_eq!(result.residual_entropy_bits, 448.0);
        assert_eq!(result.required_entropy_bits, 288.0);
        assert!(result.accepted);
    }

    #[test]
    fn rejects_when_multiple_helper_records_exhaust_budget() {
        let result = assess_enrollment(
            EntropyBudget {
                source_min_entropy_bits: 320.0,
                helper_data_leakage_bound_bits: 80.0,
                extracted_key_bits: 128.0,
                statistical_security_bits: 64.0,
                uncertainty_reserve_bits: 32.0,
            },
            EnrollmentPolicy {
                maximum_helper_data_records: 4,
                requested_helper_data_records: 3,
                minimum_residual_entropy_bits: 256.0,
            },
        )
        .expect("valid assessment");

        assert_eq!(result.residual_entropy_bits, 80.0);
        assert_eq!(result.required_entropy_bits, 288.0);
        assert!(!result.accepted);
    }

    #[test]
    fn rejects_invalid_record_count() {
        let result = assess_enrollment(
            EntropyBudget {
                source_min_entropy_bits: 256.0,
                helper_data_leakage_bound_bits: 32.0,
                extracted_key_bits: 128.0,
                statistical_security_bits: 64.0,
                uncertainty_reserve_bits: 16.0,
            },
            EnrollmentPolicy {
                maximum_helper_data_records: 1,
                requested_helper_data_records: 2,
                minimum_residual_entropy_bits: 128.0,
            },
        );

        assert_eq!(result, Err(HelperDataError::InvalidRecordCount));
    }
}
