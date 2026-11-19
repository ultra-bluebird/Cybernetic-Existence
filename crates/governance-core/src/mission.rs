#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MissionKind {
    ResearchAnalysis,
    PolicyReview,
    SafetyEnvelopeReview,
    EvidenceBundleReview,
    ReadOnlyMonitoringPlan,
    SoftwareValidation,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MissionScope {
    Civic,
    Personal,
    Medical,
    Environmental,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MissionDescriptor {
    pub mission_id: String,
    pub kind: MissionKind,
    pub scope: MissionScope,
    pub purpose: String,
    pub evidence_state: EvidenceState,
    pub review_state: ReviewState,
}
