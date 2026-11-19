#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PrivateTier {
    T0,
    T1,
    T2,
    T3,
    T4,
}

impl PrivateTier {
    pub const fn next(self) -> Option<Self> {
        match self {
            Self::T0 => Some(Self::T1),
            Self::T1 => Some(Self::T2),
            Self::T2 => Some(Self::T3),
            Self::T3 => Some(Self::T4),
            Self::T4 => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CompletenessSignals {
    pub boundary_completeness: f64,
    pub metadata_completeness: f64,
    pub evidence_completeness: f64,
    pub quality_review_completeness: f64,
    pub continuity_confirmation: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProgressionRequest {
    pub current_tier: PrivateTier,
    pub requested_tier: PrivateTier,
    pub owner_authorized: bool,
    pub noninterference_check_passed: bool,
    pub private_scope_confirmed: bool,
    pub request_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProgressionReceipt {
    pub previous_tier: PrivateTier,
    pub resulting_tier: PrivateTier,
    pub request_id: String,
    pub event_kind: String,
    pub public_export_permitted: bool,
    pub eligibility_use_permitted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProgressionError {
    InvalidSignalRange,
    IncompleteEvidence,
    MissingOwnerAuthorization,
    NonInterferenceCheckFailed,
    PublicScopeNotAllowed,
    NoFurtherTierAvailable,
    TierSkipNotAllowed,
    DowngradeNotAllowed,
    EmptyRequestId,
}

pub fn progression_complete(
    signals: CompletenessSignals,
) -> Result<bool, ProgressionError> {
    validate_signal(signals.boundary_completeness)?;
    validate_signal(signals.metadata_completeness)?;
    validate_signal(signals.evidence_completeness)?;
    validate_signal(signals.quality_review_completeness)?;

    Ok(
        signals.boundary_completeness >= 0.57
            && signals.metadata_completeness >= 0.57
            && signals.evidence_completeness >= 0.57
            && signals.quality_review_completeness >= 0.57
            && signals.continuity_confirmation,
    )
}

pub fn advance_private_tier(
    request: &ProgressionRequest,
    signals: CompletenessSignals,
) -> Result<ProgressionReceipt, ProgressionError> {
    if request.request_id.trim().is_empty() {
        return Err(ProgressionError::EmptyRequestId);
    }

    if request.requested_tier < request.current_tier {
        return Err(ProgressionError::DowngradeNotAllowed);
    }

    let next_tier = request
        .current_tier
        .next()
        .ok_or(ProgressionError::NoFurtherTierAvailable)?;

    if request.requested_tier != next_tier {
        return Err(ProgressionError::TierSkipNotAllowed);
    }

    if !progression_complete(signals)? {
        return Err(ProgressionError::IncompleteEvidence);
    }

    if !request.owner_authorized {
        return Err(ProgressionError::MissingOwnerAuthorization);
    }

    if !request.noninterference_check_passed {
        return Err(ProgressionError::NonInterferenceCheckFailed);
    }

    if !request.private_scope_confirmed {
        return Err(ProgressionError::PublicScopeNotAllowed);
    }

    Ok(ProgressionReceipt {
        previous_tier: request.current_tier,
        resulting_tier: request.requested_tier,
        request_id: request.request_id.clone(),
        event_kind: "private_forward_progression".to_owned(),
        public_export_permitted: false,
        eligibility_use_permitted: false,
    })
}

fn validate_signal(value: f64) -> Result<(), ProgressionError> {
    if !value.is_finite() || !(0.0..=1.0).contains(&value) {
        return Err(ProgressionError::InvalidSignalRange);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn complete_signals() -> CompletenessSignals {
        CompletenessSignals {
            boundary_completeness: 0.57,
            metadata_completeness: 0.82,
            evidence_completeness: 0.91,
            quality_review_completeness: 0.70,
            continuity_confirmation: true,
        }
    }

    #[test]
    fn permits_one_private_forward_transition() {
        let receipt = advance_private_tier(
            &ProgressionRequest {
                current_tier: PrivateTier::T1,
                requested_tier: PrivateTier::T2,
                owner_authorized: true,
                noninterference_check_passed: true,
                private_scope_confirmed: true,
                request_id: "progression-2026-001".to_owned(),
            },
            complete_signals(),
        )
        .expect("complete and owner-authorized progression should work");

        assert_eq!(receipt.previous_tier, PrivateTier::T1);
        assert_eq!(receipt.resulting_tier, PrivateTier::T2);
        assert!(!receipt.public_export_permitted);
        assert!(!receipt.eligibility_use_permitted);
    }

    #[test]
    fn rejects_rollback() {
        let result = advance_private_tier(
            &ProgressionRequest {
                current_tier: PrivateTier::T3,
                requested_tier: PrivateTier::T2,
                owner_authorized: true,
                noninterference_check_passed: true,
                private_scope_confirmed: true,
                request_id: "rollback-attempt".to_owned(),
            },
            complete_signals(),
        );

        assert_eq!(result, Err(ProgressionError::DowngradeNotAllowed));
    }

    #[test]
    fn rejects_skipped_tiers() {
        let result = advance_private_tier(
            &ProgressionRequest {
                current_tier: PrivateTier::T0,
                requested_tier: PrivateTier::T2,
                owner_authorized: true,
                noninterference_check_passed: true,
                private_scope_confirmed: true,
                request_id: "skip-attempt".to_owned(),
            },
            complete_signals(),
        );

        assert_eq!(result, Err(ProgressionError::TierSkipNotAllowed));
    }

    #[test]
    fn requires_explicit_continuity_confirmation() {
        let mut signals = complete_signals();
        signals.continuity_confirmation = false;

        let result = progression_complete(signals);

        assert_eq!(result, Ok(false));
    }
}
