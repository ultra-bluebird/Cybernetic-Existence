pub fn validate_mission(
    mission: &MissionDescriptor,
    evidence: &EvidenceBundle,
    envelope: &SafetyEnvelope,
) -> ValidationReport;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ValidationReport {
    pub decision: GovernanceDecision,
    pub findings: Vec<GovernanceFinding>,
}
