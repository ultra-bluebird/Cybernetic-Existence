pub const REQUIRED_EVIDENCE_TAG_COUNT: usize = 10;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum EvidenceTagKind {
    PhysicalConstraint,
    EnvironmentalConstraint,
    OperationalConstraint,
    SafetyEnvelope,
    CalibrationReference,
    MethodReference,
    ProvenanceReference,
    UncertaintyReference,
    ReviewReference,
    PolicyReference,
}

#[derive(Clone, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct EvidenceTag {
    pub kind: EvidenceTagKind,
    pub value: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EvidenceBundle {
    pub tags: [EvidenceTag; REQUIRED_EVIDENCE_TAG_COUNT],
    pub state: EvidenceState,
    pub review_state: ReviewState,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum EvidenceTagError {
    EmptyTag,
    InvalidTagFormat,
    DuplicateTag,
    InvalidTagKind,
    IncompleteEvidence,
    IdentityBearingContent,
    CredentialBearingContent,
}
