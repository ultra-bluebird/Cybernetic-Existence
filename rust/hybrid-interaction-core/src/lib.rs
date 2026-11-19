#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RoutingClass {
    TaskContent,
    ExplicitPresentationPreference,
    ContextualMarkerOnly,
    TaskRelevantMarkerTerm,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CorrectionState {
    Normal,
    CorrectionReceived,
    ScopeUpdated,
    ClarificationRequired,
    Resume,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InteractionDisposition {
    Continue,
    RewriteRequired,
    ClarificationRequired,
    ReviewRequired,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InteractionError {
    NonFiniteInput,
    InvalidRange,
    InvalidThreshold,
    InvalidTransition,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct InteractionMetrics {
    pub rule_compliance: f64,
    pub semantic_scope_fidelity: f64,
    pub blinded_review_agreement: f64,
    pub correction_rate: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuityCounts {
    pub scope_reclarifications: u64,
    pub unrequested_corrections: u64,
    pub premise_insertions: u64,
    pub unnecessary_caveats: u64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuityWeights {
    pub scope_reclarification: f64,
    pub unrequested_correction: f64,
    pub premise_insertion: f64,
    pub unnecessary_caveat: f64,
}

pub fn classify_for_routing(
    is_marker_term: bool,
    is_task_relevant: bool,
    is_explicit_presentation_preference: bool,
) -> RoutingClass {
    if is_explicit_presentation_preference {
        return RoutingClass::ExplicitPresentationPreference;
    }

    if is_marker_term && is_task_relevant {
        return RoutingClass::TaskRelevantMarkerTerm;
    }

    if is_marker_term {
        return RoutingClass::ContextualMarkerOnly;
    }

    RoutingClass::TaskContent
}

pub fn should_strip_from_substantive_routing(classification: RoutingClass) -> bool {
    matches!(classification, RoutingClass::ContextualMarkerOnly)
}

pub fn next_correction_state(
    current: CorrectionState,
    correction_is_ambiguous: bool,
    clarification_is_necessary: bool,
) -> Result<CorrectionState, InteractionError> {
    match current {
        CorrectionState::Normal => Ok(CorrectionState::CorrectionReceived),
        CorrectionState::CorrectionReceived => {
            if correction_is_ambiguous && clarification_is_necessary {
                Ok(CorrectionState::ClarificationRequired)
            } else {
                Ok(CorrectionState::ScopeUpdated)
            }
        }
        CorrectionState::ScopeUpdated => Ok(CorrectionState::Resume),
        CorrectionState::ClarificationRequired => Ok(CorrectionState::Resume),
        CorrectionState::Resume => Err(InteractionError::InvalidTransition),
    }
}

pub fn interaction_metrics_are_valid(
    metrics: InteractionMetrics,
) -> Result<bool, InteractionError> {
    let bounded = [
        metrics.rule_compliance,
        metrics.semantic_scope_fidelity,
        metrics.blinded_review_agreement,
        metrics.correction_rate,
    ];

    if bounded.iter().any(|value| !value.is_finite()) {
        return Err(InteractionError::NonFiniteInput);
    }

    if !(0.0..=1.0).contains(&metrics.rule_compliance)
        || !(0.0..=1.0).contains(&metrics.semantic_scope_fidelity)
        || !(0.0..=1.0).contains(&metrics.blinded_review_agreement)
        || metrics.correction_rate < 0.0
    {
        return Err(InteractionError::InvalidRange);
    }

    Ok(true)
}

pub fn continuity_cost(
    counts: ContinuityCounts,
    weights: ContinuityWeights,
) -> Result<f64, InteractionError> {
    let values = [
        weights.scope_reclarification,
        weights.unrequested_correction,
        weights.premise_insertion,
        weights.unnecessary_caveat,
    ];

    if values.iter().any(|value| !value.is_finite() || *value < 0.0) {
        return Err(InteractionError::InvalidRange);
    }

    Ok(
        counts.scope_reclarifications as f64 * weights.scope_reclarification
            + counts.unrequested_corrections as f64 * weights.unrequested_correction
            + counts.premise_insertions as f64 * weights.premise_insertion
            + counts.unnecessary_caveats as f64 * weights.unnecessary_caveat,
    )
}

pub fn sharp_case_audit_is_permitted(
    explicit_opt_in: bool,
    purpose_limited: bool,
    no_disclosure_equivalent_access: bool,
    aggregate_reporting: bool,
    human_review_available: bool,
) -> bool {
    explicit_opt_in
        && purpose_limited
        && no_disclosure_equivalent_access
        && aggregate_reporting
        && human_review_available
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn task_relevant_marker_term_is_preserved() {
        let classification = classify_for_routing(true, true, false);

        assert_eq!(
            classification,
            RoutingClass::TaskRelevantMarkerTerm
        );

        assert!(!should_strip_from_substantive_routing(classification));
    }

    #[test]
    fn marker_only_term_is_not_routed_as_substantive_content() {
        let classification = classify_for_routing(true, false, false);

        assert_eq!(
            classification,
            RoutingClass::ContextualMarkerOnly
        );

        assert!(should_strip_from_substantive_routing(classification));
    }

    #[test]
    fn correction_uses_clarification_only_when_necessary() {
        let next = next_correction_state(
            CorrectionState::CorrectionReceived,
            true,
            true,
        )
        .expect("valid correction transition");

        assert_eq!(next, CorrectionState::ClarificationRequired);
    }

    #[test]
    fn correction_updates_scope_when_clarification_is_not_required() {
        let next = next_correction_state(
            CorrectionState::CorrectionReceived,
            true,
            false,
        )
        .expect("valid correction transition");

        assert_eq!(next, CorrectionState::ScopeUpdated);
    }

    #[test]
    fn sharp_case_audit_requires_every_privacy_and_access_guard() {
        assert!(!sharp_case_audit_is_permitted(
            true,
            true,
            false,
            true,
            true,
        ));

        assert!(sharp_case_audit_is_permitted(
            true,
            true,
            true,
            true,
            true,
        ));
    }
}
