#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RecommendationKind {
    Observe,
    HoldForReview,
    Escalate,
    PassiveDesignReview,
    Reject,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum GovernanceFinding {
    EvidenceIncomplete,
    EvidenceExpired,
    EvidenceConflict,
    EvidenceIdentityViolation,
    MissingUncertainty,
    MissingReview,
    CorridorViolation,
    RoHCeilingExceeded,
    UnknownRequiredInput,
    NonMonotoneEnvelope,
    NonActuatingOnly,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GovernanceDecision {
    pub recommendation: RecommendationKind,
    pub findings: Vec<GovernanceFinding>,
    pub evidence_state: EvidenceState,
    pub review_state: ReviewState,
    pub rationale: String,
}
