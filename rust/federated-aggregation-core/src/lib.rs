#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FederatedRoundStatus {
    Eligible,
    Ineligible,
    Indeterminate,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FederatedError {
    NonFiniteInput,
    DimensionMismatch,
    InvalidPrivacyParameters,
    InvalidMinimumCohort,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LocalUpdate {
    pub values: Vec<f64>,
    pub participant_weight: u64,
    pub consent_valid: bool,
    pub purpose_allowed: bool,
    pub privacy_budget_remaining: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RoundPolicy {
    pub minimum_participants: usize,
    pub clipping_norm: f64,
    pub minimum_privacy_budget_remaining: f64,
    pub secure_aggregation_ready: bool,
    pub model_release_approved: bool,
}

pub fn clip_l2(
    update: &[f64],
    clipping_norm: f64,
) -> Result<Vec<f64>, FederatedError> {
    if !clipping_norm.is_finite() || clipping_norm <= 0.0 {
        return Err(FederatedError::InvalidPrivacyParameters);
    }

    if update.iter().any(|value| !value.is_finite()) {
        return Err(FederatedError::NonFiniteInput);
    }

    let norm_squared: f64 = update.iter().map(|value| value * value).sum();
    let norm = norm_squared.sqrt();

    if !norm.is_finite() {
        return Err(FederatedError::NonFiniteInput);
    }

    let scale = if norm > clipping_norm {
        clipping_norm / norm
    } else {
        1.0
    };

    Ok(update.iter().map(|value| value * scale).collect())
}

pub fn round_status(
    updates: &[LocalUpdate],
    policy: RoundPolicy,
) -> Result<FederatedRoundStatus, FederatedError> {
    if policy.minimum_participants == 0 {
        return Err(FederatedError::InvalidMinimumCohort);
    }

    if !policy.clipping_norm.is_finite()
        || policy.clipping_norm <= 0.0
        || !policy.minimum_privacy_budget_remaining.is_finite()
        || policy.minimum_privacy_budget_remaining < 0.0
    {
        return Err(FederatedError::InvalidPrivacyParameters);
    }

    if !policy.secure_aggregation_ready || !policy.model_release_approved {
        return Ok(FederatedRoundStatus::Ineligible);
    }

    let eligible = updates
        .iter()
        .filter(|update| {
            update.consent_valid
                && update.purpose_allowed
                && update.privacy_budget_remaining
                    >= policy.minimum_privacy_budget_remaining
                && update.participant_weight > 0
                && update.values.iter().all(|value| value.is_finite())
        })
        .count();

    if eligible < policy.minimum_participants {
        return Ok(FederatedRoundStatus::Ineligible);
    }

    Ok(FederatedRoundStatus::Eligible)
}

pub fn weighted_sum_of_clipped_updates(
    updates: &[LocalUpdate],
    clipping_norm: f64,
) -> Result<Vec<f64>, FederatedError> {
    if updates.is_empty() {
        return Err(FederatedError::DimensionMismatch);
    }

    let dimensions = updates[0].values.len();

    if dimensions == 0
        || updates
            .iter()
            .any(|update| update.values.len() != dimensions)
    {
        return Err(FederatedError::DimensionMismatch);
    }

    let mut total = vec![0.0_f64; dimensions];

    for update in updates {
        let clipped = clip_l2(&update.values, clipping_norm)?;
        let weight = update.participant_weight as f64;

        for (total_value, update_value) in total.iter_mut().zip(clipped) {
            *total_value += weight * update_value;
        }
    }

    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clipping_limits_update_norm() {
        let clipped = clip_l2(&[3.0, 4.0], 2.0).expect("valid vector");
        let norm = clipped.iter().map(|value| value * value).sum::<f64>().sqrt();

        assert!((norm - 2.0).abs() < 1e-12);
    }

    #[test]
    fn insufficient_cohort_blocks_federated_round() {
        let status = round_status(
            &[LocalUpdate {
                values: vec![0.1, 0.2],
                participant_weight: 1,
                consent_valid: true,
                purpose_allowed: true,
                privacy_budget_remaining: 1.0,
            }],
            RoundPolicy {
                minimum_participants: 2,
                clipping_norm: 1.0,
                minimum_privacy_budget_remaining: 0.1,
                secure_aggregation_ready: true,
                model_release_approved: true,
            },
        )
        .expect("valid round policy");

        assert_eq!(status, FederatedRoundStatus::Ineligible);
    }
}
