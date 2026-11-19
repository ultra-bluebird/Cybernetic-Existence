#![forbid(unsafe_code)]

use std::fmt::Write;

#[derive(Debug, Clone, PartialEq)]
pub struct GovernanceRunnerRow {
    pub node_id: String,
    pub contaminant: String,
    pub kn: f64,
    pub eco_impact_score: f64,
    pub mintcap_tokens: f64,
    pub burndue_tokens: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GovernanceRunnerError {
    NonFiniteInput,
    NonFiniteOutput,
}

pub fn compute_token_adjustments(
    kn: f64,
    hazard_weight: f64,
) -> Result<(f64, f64, f64), GovernanceRunnerError> {
    if !kn.is_finite() || !hazard_weight.is_finite() || hazard_weight < 0.0 {
        return Err(GovernanceRunnerError::NonFiniteInput);
    }

    let eco_impact_score = kn * hazard_weight;
    if !eco_impact_score.is_finite() {
        return Err(GovernanceRunnerError::NonFiniteOutput);
    }

    let mintcap_tokens = eco_impact_score.max(0.0);
    let burndue_tokens = eco_impact_score.min(0.0);

    if !mintcap_tokens.is_finite() || !burndue_tokens.is_finite() {
        return Err(GovernanceRunnerError::NonFiniteOutput);
    }

    Ok((eco_impact_score, mintcap_tokens, burndue_tokens))
}

pub fn format_csv_decimal(value: f64) -> Result<String, GovernanceRunnerError> {
    if !value.is_finite() {
        return Err(GovernanceRunnerError::NonFiniteOutput);
    }

    let normalized = if value == 0.0 { 0.0 } else { value };
    let mut output = String::with_capacity(32);

    write!(&mut output, "{normalized:.6}")
        .map_err(|_| GovernanceRunnerError::NonFiniteOutput)?;

    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn negative_impact_produces_negative_burn_due() {
        let (impact, mint, burn) =
            compute_token_adjustments(-0.5, 0.8).expect("finite inputs");

        assert_eq!(impact, -0.4);
        assert_eq!(mint, 0.0);
        assert_eq!(burn, -0.4);
        assert_eq!(
            format_csv_decimal(burn).expect("finite output"),
            "-0.400000"
        );
    }

    #[test]
    fn positive_impact_produces_no_burn_due() {
        let (impact, mint, burn) =
            compute_token_adjustments(0.5, 0.8).expect("finite inputs");

        assert_eq!(impact, 0.4);
        assert_eq!(mint, 0.4);
        assert_eq!(burn, 0.0);
        assert_eq!(
            format_csv_decimal(burn).expect("finite output"),
            "0.000000"
        );
    }

    #[test]
    fn negative_zero_is_normalized_for_export() {
        assert_eq!(
            format_csv_decimal(-0.0).expect("finite output"),
            "0.000000"
        );
    }

    #[test]
    fn non_finite_values_are_rejected() {
        assert_eq!(
            compute_token_adjustments(f64::NAN, 0.8),
            Err(GovernanceRunnerError::NonFiniteInput)
        );

        assert_eq!(
            format_csv_decimal(f64::INFINITY),
            Err(GovernanceRunnerError::NonFiniteOutput)
        );
    }
}
