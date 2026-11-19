#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub enum EvidenceState {
    VerifiedFact,
    CalibratedEstimate,
    ScreeningEstimate,
    ModelOutput,
    Hypothesis,
    Unknown,
    Unmodeled,
    Expired,
    ReviewRequired,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ReviewState {
    NotRequired,
    Required,
    Completed,
    Rejected,
}
