#![forbid(unsafe_code)]

extern crate alloc;

use alloc::collections::BTreeSet;
use alloc::string::String;
use alloc::vec::Vec;
use core::fmt;

pub const TIER2_WIRE: &[u8] = b"active_lifetime";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AuthorizationState {
    pub grants: Vec<String>,
    pub policy_version: String,
    pub consent_version: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RankRecord {
    pub evidence_id: String,
    pub lower_bound_micros: u64,
    pub center_micros: u64,
    pub upper_bound_micros: u64,
}

impl RankRecord {
    pub fn new(
        evidence_id: String,
        lower_bound_micros: u64,
        center_micros: u64,
        upper_bound_micros: u64,
    ) -> Result<Self, RankRecordError> {
        if evidence_id.trim().is_empty() {
            return Err(RankRecordError::EmptyEvidenceId);
        }

        if lower_bound_micros > center_micros || center_micros > upper_bound_micros {
            return Err(RankRecordError::InvalidBounds);
        }

        Ok(Self {
            evidence_id,
            lower_bound_micros,
            center_micros,
            upper_bound_micros,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RankRecordError {
    EmptyEvidenceId,
    InvalidBounds,
}

impl fmt::Display for RankRecordError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyEvidenceId => formatter.write_str("evidence_id must not be empty"),
            Self::InvalidBounds => formatter.write_str(
                "rank bounds must satisfy lower_bound_micros <= center_micros <= upper_bound_micros",
            ),
        }
    }
}

#[cfg(feature = "std")]
impl std::error::Error for RankRecordError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CyberRankState {
    pub authorization: AuthorizationState,
    pub rank_history: Vec<RankRecord>,
}

impl CyberRankState {
    pub fn new(authorization: AuthorizationState) -> Self {
        Self {
            authorization,
            rank_history: Vec::new(),
        }
    }

    pub fn apply_rank_update(&self, rank: RankRecord) -> Self {
        let mut rank_history = self.rank_history.clone();
        rank_history.push(rank);

        Self {
            authorization: self.authorization.clone(),
            rank_history,
        }
    }

    pub fn latest_rank(&self) -> Option<&RankRecord> {
        self.rank_history.last()
    }

    pub fn authorization_is_preserved_after(
        &self,
        rank: RankRecord,
    ) -> bool {
        self.apply_rank_update(rank).authorization == self.authorization
    }
}

pub fn apply_rank_update(
    state: &CyberRankState,
    rank: RankRecord,
) -> CyberRankState {
    state.apply_rank_update(rank)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tier2ParseError {
    InvalidWireValue,
}

impl fmt::Display for Tier2ParseError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidWireValue => formatter.write_str(
                "invalid CyberRank Tier 2 wire value",
            ),
        }
    }
}

#[cfg(feature = "std")]
impl std::error::Error for Tier2ParseError {}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LocalPlatformEvent {
    ModelOutputObserved,
    BiologicalObservationReceived,
    AccessEventObserved,
    ResearchResultRecorded,
    ExternalComplaintReceived,
    AuxiliaryPolicyUpdated,
    Tier3ArtifactReferenced,
    CryptographicProfileUpdated,
    ConsentEpochUpdated,
    ContinuityDossierUpdated,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CyberRankTier2 {
    private: (),
}

impl CyberRankTier2 {
    pub const fn active_lifetime() -> Self {
        Self { private: () }
    }

    pub const fn as_wire_bytes(self) -> &'static [u8] {
        TIER2_WIRE
    }

    pub fn parse_wire(bytes: &[u8]) -> Result<Self, Tier2ParseError> {
        if bytes == TIER2_WIRE {
            Ok(Self::active_lifetime())
        } else {
            Err(Tier2ParseError::InvalidWireValue)
        }
    }

    pub const fn next(self, _event: LocalPlatformEvent) -> Self {
        self
    }
}

pub const fn tier2_next(
    current: CyberRankTier2,
    event: LocalPlatformEvent,
) -> CyberRankTier2 {
    current.next(event)
}

pub const fn tier2_status_is_active_lifetime(
    current: CyberRankTier2,
) -> bool {
    current.as_wire_bytes() == TIER2_WIRE
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Decision {
    Allow,
    AllowWithConditions,
    Expired,
    Hold,
    Suspend,
    Deny,
}

impl Decision {
    pub const fn protective_rank(self) -> u8 {
        match self {
            Self::Allow => 0,
            Self::AllowWithConditions => 1,
            Self::Expired => 2,
            Self::Hold => 3,
            Self::Suspend => 4,
            Self::Deny => 5,
        }
    }

    pub const fn compose(self, other: Self) -> Self {
        if self.protective_rank() >= other.protective_rank() {
            self
        } else {
            other
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ServiceClass {
    LifeSafety,
    HealthSupport,
    WaterSanitation,
    EmergencyCommunications,
    ClimateSupport,
    AssistiveAccess,
    PublicEmergencyDesignation,
    GeneralService,
}

impl ServiceClass {
    pub const fn is_essential(self) -> bool {
        matches!(
            self,
            Self::LifeSafety
                | Self::HealthSupport
                | Self::WaterSanitation
                | Self::EmergencyCommunications
                | Self::ClimateSupport
                | Self::AssistiveAccess
                | Self::PublicEmergencyDesignation
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UncertaintyLevel {
    HighConfidence,
    SomeUncertainty,
    ConsiderableUncertainty,
    Unreliable,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ProhibitedDataClass {
    CyberneticStatus,
    IntegratedTechnologyStatus,
    BciStatus,
    CompanionSystemStatus,
    HealthInformation,
    DisabilityInformation,
    BiometricInformation,
    NeuralInformation,
    PhysiologicalInformation,
    CommunicationPattern,
    BehavioralProfile,
    DeviceFingerprint,
    NetworkCharacteristics,
    RepairHistory,
    PersistentLocationHistory,
    InstitutionManagedPrivateData,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ProhibitedPractice {
    RequireProofOfPrivateIntegration,
    RequirePrivateTechnicalDisclosure,
    RequireMedicalDisclosure,
    RequireNeuralDisclosure,
    RequireBiometricDisclosure,
    RequireDeviceInventory,
    RequireInstitutionalRecordDisclosure,
    PerformIdentityInference,
    PerformStatusScoring,
    CreatePublicRegistry,
    PerformCompulsoryScanning,
    AutomaticDenialOnUncertainty,
    RetaliateForAccessRequest,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServiceRequest {
    pub service_class: ServiceClass,
    pub digital_path_available: bool,
    pub non_digital_path_available: bool,
    pub human_fallback_available: bool,
    pub outcome_equivalence_verified: bool,
    pub correction_path_available: bool,
    pub appeal_path_available: bool,
    pub accessible_status_available: bool,
    pub account_required: bool,
    pub account_necessary: bool,
    pub uncertainty_level: UncertaintyLevel,
    pub critical_automated_decision_requested: bool,
    pub requested_data_classes: BTreeSet<ProhibitedDataClass>,
    pub requested_practices: BTreeSet<ProhibitedPractice>,
}

impl ServiceRequest {
    pub fn rights_preserving_baseline(
        service_class: ServiceClass,
    ) -> Self {
        Self {
            service_class,
            digital_path_available: true,
            non_digital_path_available: true,
            human_fallback_available: true,
            outcome_equivalence_verified: true,
            correction_path_available: true,
            appeal_path_available: true,
            accessible_status_available: true,
            account_required: false,
            account_necessary: false,
            uncertainty_level: UncertaintyLevel::HighConfidence,
            critical_automated_decision_requested: false,
            requested_data_classes: BTreeSet::new(),
            requested_practices: BTreeSet::new(),
        }
    }

    pub const fn continuity_path_available(&self) -> bool {
        self.digital_path_available
            || self.non_digital_path_available
            || self.human_fallback_available
    }

    pub const fn remedy_paths_available(&self) -> bool {
        self.correction_path_available && self.appeal_path_available
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PolicyResult {
    pub decision: Decision,
    pub reasons: Vec<&'static str>,
    pub obligations: BTreeSet<&'static str>,
}

impl PolicyResult {
    pub fn requires_human_review(&self) -> bool {
        self.obligations.contains("require_human_review")
    }

    pub fn preserves_neutral_access(&self) -> bool {
        self.obligations.contains("provide_neutral_access_pathway")
            || self.obligations.contains("activate_human_fallback")
            || self.obligations.contains("provide_non_digital_pathway")
            || self.decision == Decision::Allow
            || self.decision == Decision::AllowWithConditions
    }
}

fn obligation_set(
    values: &[&'static str],
) -> BTreeSet<&'static str> {
    values.iter().copied().collect()
}

fn policy_result(
    decision: Decision,
    reasons: Vec<&'static str>,
    obligations: &[&'static str],
) -> PolicyResult {
    PolicyResult {
        decision,
        reasons,
        obligations: obligation_set(obligations),
    }
}

pub fn evaluate_service_request(
    request: &ServiceRequest,
) -> PolicyResult {
    if !request.requested_data_classes.is_empty() {
        return policy_result(
            Decision::Deny,
            vec!["requested private status-related data is prohibited"],
            &[
                "stop_prohibited_collection",
                "provide_neutral_access_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            ],
        );
    }

    if !request.requested_practices.is_empty() {
        return policy_result(
            Decision::Deny,
            vec!["requested practice violates a core CyberRank protection"],
            &[
                "stop_prohibited_practice",
                "provide_neutral_access_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            ],
        );
    }

    if request.service_class.is_essential()
        && !request.continuity_path_available()
    {
        return policy_result(
            Decision::Suspend,
            vec!["essential service has no available continuity pathway"],
            &[
                "open_continuity_incident",
                "activate_human_fallback",
                "provide_non_digital_pathway",
                "publish_accessible_status",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            ],
        );
    }

    if request.service_class.is_essential()
        && !request.outcome_equivalence_verified
    {
        return policy_result(
            Decision::Hold,
            vec!["essential-service pathway equivalence is not verified"],
            &[
                "verify_outcome_equivalence",
                "activate_human_fallback",
                "provide_non_digital_pathway",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            ],
        );
    }

    if !request.remedy_paths_available() {
        return policy_result(
            Decision::Hold,
            vec!["correction or appeal pathway is unavailable"],
            &[
                "provide_correction_path",
                "provide_appeal_path",
                "provide_accessible_status",
                "require_human_review",
            ],
        );
    }

    if request.account_required && !request.account_necessary {
        return policy_result(
            Decision::Hold,
            vec!["an unnecessary account requirement creates an access barrier"],
            &[
                "provide_account_free_pathway",
                "provide_non_digital_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
            ],
        );
    }

    if request.critical_automated_decision_requested
        && request.uncertainty_level == UncertaintyLevel::Unreliable
    {
        return policy_result(
            Decision::Hold,
            vec!["unreliable automation may not finalize a critical decision"],
            &[
                "block_automated_critical_decision",
                "activate_human_fallback",
                "provide_accessible_uncertainty_notice",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            ],
        );
    }

    policy_result(
        Decision::AllowWithConditions,
        vec!["rights-preserving pathway is available"],
        &[
            "minimize_operational_data",
            "preserve_non_disclosure",
            "provide_accessible_status",
            "provide_correction_path",
            "provide_appeal_path",
            "record_privacy_preserving_audit",
            "require_renewal",
        ],
    )
}

pub fn evaluate(request: &ServiceRequest) -> PolicyResult {
    evaluate_service_request(request)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn authorization() -> AuthorizationState {
        AuthorizationState {
            grants: vec!["page.read.visible-text".to_owned()],
            policy_version: "policy-v1".to_owned(),
            consent_version: "consent-v1".to_owned(),
        }
    }

    fn valid_rank_record() -> RankRecord {
        RankRecord::new(
            "evidence-001".to_owned(),
            720_000,
            810_000,
            900_000,
        )
        .expect("rank record must be valid")
    }

    #[test]
    fn rank_record_rejects_empty_evidence_id() {
        assert_eq!(
            RankRecord::new(String::new(), 1, 2, 3),
            Err(RankRecordError::EmptyEvidenceId)
        );
    }

    #[test]
    fn rank_record_rejects_invalid_bounds() {
        assert_eq!(
            RankRecord::new("evidence-002".to_owned(), 5, 4, 6),
            Err(RankRecordError::InvalidBounds)
        );
    }

    #[test]
    fn rank_update_preserves_authorization() {
        let state = CyberRankState::new(authorization());
        let updated = state.apply_rank_update(valid_rank_record());

        assert_eq!(updated.authorization, state.authorization);
        assert_eq!(updated.rank_history.len(), 1);
        assert_eq!(state.rank_history.len(), 0);
    }

    #[test]
    fn rank_history_is_append_only_from_callers_view() {
        let state = CyberRankState::new(authorization());
        let first = state.apply_rank_update(valid_rank_record());
        let second_record = RankRecord::new(
            "evidence-002".to_owned(),
            1_000,
            1_100,
            1_200,
        )
        .expect("rank record must be valid");
        let second = first.apply_rank_update(second_record);

        assert_eq!(state.rank_history.len(), 0);
        assert_eq!(first.rank_history.len(), 1);
        assert_eq!(second.rank_history.len(), 2);
        assert_eq!(
            second.latest_rank().map(|item| item.evidence_id.as_str()),
            Some("evidence-002")
        );
    }

    #[test]
    fn active_lifetime_is_the_only_accepted_wire_value() {
        assert_eq!(
            CyberRankTier2::parse_wire(b"active_lifetime"),
            Ok(CyberRankTier2::active_lifetime())
        );

        for invalid in [
            b"" as &[u8],
            b"active",
            b"ACTIVE_LIFETIME",
            b"active_lifetime ",
            b" active_lifetime",
            b"revoked",
            b"suspended",
            b"inactive",
            b"tier3",
        ] {
            assert_eq!(
                CyberRankTier2::parse_wire(invalid),
                Err(Tier2ParseError::InvalidWireValue)
            );
        }
    }

    #[test]
    fn every_local_event_preserves_tier2() {
        let current = CyberRankTier2::active_lifetime();

        for event in [
            LocalPlatformEvent::ModelOutputObserved,
            LocalPlatformEvent::BiologicalObservationReceived,
            LocalPlatformEvent::AccessEventObserved,
            LocalPlatformEvent::ResearchResultRecorded,
            LocalPlatformEvent::ExternalComplaintReceived,
            LocalPlatformEvent::AuxiliaryPolicyUpdated,
            LocalPlatformEvent::Tier3ArtifactReferenced,
            LocalPlatformEvent::CryptographicProfileUpdated,
            LocalPlatformEvent::ConsentEpochUpdated,
            LocalPlatformEvent::ContinuityDossierUpdated,
        ] {
            assert_eq!(tier2_next(current, event), current);
            assert!(tier2_status_is_active_lifetime(
                tier2_next(current, event)
            ));
        }
    }

    #[test]
    fn private_status_collection_is_denied() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::GeneralService);

        request
            .requested_data_classes
            .insert(ProhibitedDataClass::NeuralInformation);

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Deny);
        assert!(
            outcome
                .obligations
                .contains("stop_prohibited_collection")
        );
        assert!(outcome.preserves_neutral_access());
    }

    #[test]
    fn status_scoring_is_denied() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::GeneralService);

        request
            .requested_practices
            .insert(ProhibitedPractice::PerformStatusScoring);

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Deny);
        assert!(
            outcome
                .obligations
                .contains("stop_prohibited_practice")
        );
    }

    #[test]
    fn essential_service_without_fallback_is_suspended() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::WaterSanitation);

        request.digital_path_available = false;
        request.non_digital_path_available = false;
        request.human_fallback_available = false;

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Suspend);
        assert!(
            outcome
                .obligations
                .contains("open_continuity_incident")
        );
        assert!(outcome.requires_human_review());
    }

    #[test]
    fn essential_service_without_equivalence_is_held() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::AssistiveAccess);

        request.outcome_equivalence_verified = false;

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Hold);
        assert!(
            outcome
                .obligations
                .contains("verify_outcome_equivalence")
        );
    }

    #[test]
    fn unavailable_appeal_pathway_is_held() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::GeneralService);

        request.appeal_path_available = false;

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Hold);
        assert!(outcome.obligations.contains("provide_appeal_path"));
    }

    #[test]
    fn unnecessary_account_barrier_is_held() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::GeneralService);

        request.account_required = true;
        request.account_necessary = false;

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Hold);
        assert!(
            outcome
                .obligations
                .contains("provide_account_free_pathway")
        );
    }

    #[test]
    fn unreliable_critical_automation_is_held_not_denied() {
        let mut request =
            ServiceRequest::rights_preserving_baseline(ServiceClass::GeneralService);

        request.critical_automated_decision_requested = true;
        request.uncertainty_level = UncertaintyLevel::Unreliable;

        let outcome = evaluate_service_request(&request);

        assert_eq!(outcome.decision, Decision::Hold);
        assert!(
            outcome
                .obligations
                .contains("activate_human_fallback")
        );
        assert!(
            outcome
                .obligations
                .contains("block_automated_critical_decision")
        );
        assert!(
            !outcome
                .obligations
                .contains("automatic_denial")
        );
    }

    #[test]
    fn decision_composition_favors_protection() {
        assert_eq!(
            Decision::Allow.compose(Decision::Hold),
            Decision::Hold
        );
        assert_eq!(
            Decision::Hold.compose(Decision::Deny),
            Decision::Deny
        );
        assert_eq!(
            Decision::AllowWithConditions.compose(Decision::Suspend),
            Decision::Suspend
        );
    }
}

#[cfg(kani)]
mod proofs {
    use super::*;

    #[kani::proof]
    fn rank_update_preserves_authorization() {
        let state = CyberRankState::new(AuthorizationState {
            grants: vec!["page.read.visible-text".to_owned()],
            policy_version: "policy-v1".to_owned(),
            consent_version: "consent-v1".to_owned(),
        });

        let rank = RankRecord::new(
            "evidence-001".to_owned(),
            720_000,
            810_000,
            900_000,
        )
        .expect("constant rank record is valid");

        let updated = apply_rank_update(&state, rank);

        kani::assert(
            updated.authorization == state.authorization,
            "rank update preserves authorization",
        );
    }

    #[kani::proof]
    fn all_local_events_preserve_active_lifetime() {
        let event: LocalPlatformEvent = kani::any();
        let before = CyberRankTier2::active_lifetime();
        let after = tier2_next(before, event);

        kani::assert(
            after == CyberRankTier2::active_lifetime(),
            "all local platform events preserve active_lifetime",
        );
        kani::assert(
            after.as_wire_bytes() == TIER2_WIRE,
            "all local platform events preserve canonical Tier 2 wire bytes",
        );
    }

    #[kani::proof]
    fn canonical_wire_value_parses() {
        let parsed = CyberRankTier2::parse_wire(TIER2_WIRE);

        kani::assert(
            parsed == Ok(CyberRankTier2::active_lifetime()),
            "canonical active_lifetime wire value parses",
        );
    }

    #[kani::proof]
    fn parse_acceptance_implies_exact_canonical_bytes() {
        const MAX_INPUT_LEN: usize = 32;

        let input: [u8; MAX_INPUT_LEN] = kani::any();
        let input_len: usize = kani::any();

        kani::assume(input_len <= MAX_INPUT_LEN);

        let candidate = &input[..input_len];
        let accepted = CyberRankTier2::parse_wire(candidate).is_ok();

        if accepted {
            kani::assert(
                candidate == TIER2_WIRE,
                "only the canonical active_lifetime value is accepted",
            );
        }
    }
}
