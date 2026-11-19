#![forbid(unsafe_code)]

//! Non-extractive hero-title integrity rules.
//!
//! A hero title is a non-transferable recognition state. It cannot be redeemed
//! for money, used as collateral, sold, assigned, or converted into authority
//! over another person. A credible extraction report creates a due-process
//! review requirement; it does not impose an automatic final adverse finding.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TitleStatus {
    Active,
    UnderReview,
    SuspendedPendingReview,
    RevokedAfterFinalReview,
    Restored,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TitleAction {
    CivicContribution,
    RequestNonCashMaintenanceSupport,
    AttemptCashRedemption,
    AttemptTransfer,
    AttemptCollateralization,
    AttemptCoerciveAuthority,
    AllegedMisrepresentation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IntegrityDecision {
    PermitBoundedSupport,
    RejectNonExtractiveViolation,
    RequireNeutralReview,
    PreserveStatusPendingEvidence,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IntegrityResult {
    pub next_status: TitleStatus,
    pub decision: IntegrityDecision,
    pub reason: &'static str,
}

pub fn evaluate_title_action(
    current_status: TitleStatus,
    action: TitleAction,
    credible_evidence_present: bool,
) -> IntegrityResult {
    match current_status {
        TitleStatus::RevokedAfterFinalReview => IntegrityResult {
            next_status: TitleStatus::RevokedAfterFinalReview,
            decision: IntegrityDecision::RejectNonExtractiveViolation,
            reason: "A revoked title cannot provide support until a valid restoration process completes.",
        },
        TitleStatus::SuspendedPendingReview | TitleStatus::UnderReview => IntegrityResult {
            next_status: current_status,
            decision: IntegrityDecision::RequireNeutralReview,
            reason: "Title status is already in a review state and cannot be used for new support requests.",
        },
        TitleStatus::Active | TitleStatus::Restored => match action {
            TitleAction::CivicContribution => IntegrityResult {
                next_status: current_status,
                decision: IntegrityDecision::PreserveStatusPendingEvidence,
                reason: "Civic contribution is compatible with non-extractive recognition.",
            },
            TitleAction::RequestNonCashMaintenanceSupport => IntegrityResult {
                next_status: current_status,
                decision: IntegrityDecision::PermitBoundedSupport,
                reason: "A bounded non-cash support request is compatible with title integrity.",
            },
            TitleAction::AttemptCashRedemption
            | TitleAction::AttemptTransfer
            | TitleAction::AttemptCollateralization
            | TitleAction::AttemptCoerciveAuthority => {
                if credible_evidence_present {
                    IntegrityResult {
                        next_status: TitleStatus::UnderReview,
                        decision: IntegrityDecision::RequireNeutralReview,
                        reason: "A possible extraction attempt requires neutral review, notice, evidence access, and appeal.",
                    }
                } else {
                    IntegrityResult {
                        next_status: current_status,
                        decision: IntegrityDecision::RejectNonExtractiveViolation,
                        reason: "The requested conversion is prohibited and no status conclusion is made without credible evidence.",
                    }
                }
            }
            TitleAction::AllegedMisrepresentation => {
                if credible_evidence_present {
                    IntegrityResult {
                        next_status: TitleStatus::UnderReview,
                        decision: IntegrityDecision::RequireNeutralReview,
                        reason: "A credible misrepresentation report requires a neutral, accessible review process.",
                    }
                } else {
                    IntegrityResult {
                        next_status: current_status,
                        decision: IntegrityDecision::PreserveStatusPendingEvidence,
                        reason: "An unsupported allegation does not change title status.",
                    }
                }
            }
        },
    }
}

pub fn is_non_extractive_support_request(action: TitleAction) -> bool {
    matches!(action, TitleAction::RequestNonCashMaintenanceSupport)
}

#[cfg(test)]
mod tests {
    use super::{
        evaluate_title_action, is_non_extractive_support_request, IntegrityDecision,
        TitleAction, TitleStatus,
    };

    #[test]
    fn bounded_non_cash_support_preserves_active_status() {
        let result = evaluate_title_action(
            TitleStatus::Active,
            TitleAction::RequestNonCashMaintenanceSupport,
            false,
        );

        assert_eq!(result.next_status, TitleStatus::Active);
        assert_eq!(result.decision, IntegrityDecision::PermitBoundedSupport);
    }

    #[test]
    fn cash_redemption_is_never_permitted() {
        let result = evaluate_title_action(
            TitleStatus::Active,
            TitleAction::AttemptCashRedemption,
            false,
        );

        assert_eq!(result.next_status, TitleStatus::Active);
        assert_eq!(
            result.decision,
            IntegrityDecision::RejectNonExtractiveViolation
        );
    }

    #[test]
    fn credible_collateralization_evidence_requires_review() {
        let result = evaluate_title_action(
            TitleStatus::Active,
            TitleAction::AttemptCollateralization,
            true,
        );

        assert_eq!(result.next_status, TitleStatus::UnderReview);
        assert_eq!(result.decision, IntegrityDecision::RequireNeutralReview);
    }

    #[test]
    fn unsupported_allegation_does_not_change_status() {
        let result = evaluate_title_action(
            TitleStatus::Active,
            TitleAction::AllegedMisrepresentation,
            false,
        );

        assert_eq!(result.next_status, TitleStatus::Active);
        assert_eq!(
            result.decision,
            IntegrityDecision::PreserveStatusPendingEvidence
        );
    }

    #[test]
    fn only_non_cash_maintenance_support_is_extractively_safe() {
        assert!(is_non_extractive_support_request(
            TitleAction::RequestNonCashMaintenanceSupport
        ));
        assert!(!is_non_extractive_support_request(
            TitleAction::AttemptTransfer
        ));
    }
}
