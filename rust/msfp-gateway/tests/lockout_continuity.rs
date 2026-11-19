#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RecoveryState {
    Active,
    AuthorityOff,
    TrafficBlocked,
    EvidenceSealed,
    LocalAccessConfirmed,
    Cold,
}

#[derive(Debug)]
struct RecoveryModel {
    state: RecoveryState,
    external_authority: bool,
    local_controls_available: bool,
    accessible_status_available: bool,
    human_fallback_available: bool,
    evidence_sealed: bool,
    fresh_admission_required: bool,
}

impl RecoveryModel {
    fn new() -> Self {
        Self {
            state: RecoveryState::Active,
            external_authority: true,
            local_controls_available: true,
            accessible_status_available: true,
            human_fallback_available: true,
            evidence_sealed: false,
            fresh_admission_required: false,
        }
    }

    fn remove_external_authority(&mut self) {
        assert_eq!(self.state, RecoveryState::Active);
        self.external_authority = false;
        self.fresh_admission_required = true;
        self.state = RecoveryState::AuthorityOff;
    }

    fn block_traffic(&mut self) {
        assert_eq!(self.state, RecoveryState::AuthorityOff);
        self.state = RecoveryState::TrafficBlocked;
    }

    fn seal_evidence(&mut self) {
        assert_eq!(self.state, RecoveryState::TrafficBlocked);
        self.evidence_sealed = true;
        self.state = RecoveryState::EvidenceSealed;
    }

    fn confirm_local_access(&mut self) {
        assert_eq!(self.state, RecoveryState::EvidenceSealed);
        assert!(self.local_controls_available);
        assert!(self.accessible_status_available);
        assert!(self.human_fallback_available);
        self.state = RecoveryState::LocalAccessConfirmed;
    }

    fn return_cold(&mut self) {
        assert_eq!(self.state, RecoveryState::LocalAccessConfirmed);
        assert!(!self.external_authority);
        assert!(self.evidence_sealed);
        assert!(self.fresh_admission_required);
        self.state = RecoveryState::Cold;
    }
}

#[test]
fn lockout_preserves_local_controls_and_human_fallback() {
    let mut recovery = RecoveryModel::new();

    recovery.remove_external_authority();

    assert!(!recovery.external_authority);
    assert!(recovery.local_controls_available);
    assert!(recovery.accessible_status_available);
    assert!(recovery.human_fallback_available);

    recovery.block_traffic();
    recovery.seal_evidence();
    recovery.confirm_local_access();
    recovery.return_cold();

    assert_eq!(recovery.state, RecoveryState::Cold);
    assert!(!recovery.external_authority);
    assert!(recovery.local_controls_available);
    assert!(recovery.accessible_status_available);
    assert!(recovery.human_fallback_available);
    assert!(recovery.fresh_admission_required);
}
