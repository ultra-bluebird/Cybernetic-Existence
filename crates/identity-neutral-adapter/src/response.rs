use governance_core::{
    EvidenceState,
    GovernanceDecision,
    RecommendationKind,
    ReviewState,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AssessmentResponseStatus {
    ReadyForReadOnlyImplementation,
    HoldForReview,
    Rejected,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AssessmentResponse {
    pub request_id: String,
    pub status: AssessmentResponseStatus,
    pub decision: GovernanceDecision,
    pub evidence_state: EvidenceState,
    pub review_state: ReviewState,
    pub limitations: Vec<String>,
    pub required_next_step: RecommendationKind,
}
