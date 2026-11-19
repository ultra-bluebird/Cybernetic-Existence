use std::collections::BTreeSet;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ServiceClass {
    Essential,
    NonEssential,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum DataClass {
    Identity,
    Financial,
    Neural,
    Biometric,
    Health,
    Augmentation,
    Telemetry,
    Location,
    AccessibilityNeed,
    ServiceRequest,
}

impl DataClass {
    pub const fn is_sensitive(self) -> bool {
        matches!(
            self,
            Self::Financial
                | Self::Neural
                | Self::Biometric
                | Self::Health
                | Self::Augmentation
                | Self::Telemetry
                | Self::Location
                | Self::AccessibilityNeed
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ProcessingPurpose {
    EssentialServiceFulfillment,
    EmergencySafety,
    AccessibilityAccommodation,
    Correction,
    Appeal,
    Review,
    OptionalAnalytics,
    CommercialProfiling,
    FinancialRanking,
    SocialRanking,
}

impl ProcessingPurpose {
    pub const fn is_prohibited(self) -> bool {
        matches!(
            self,
            Self::CommercialProfiling | Self::FinancialRanking | Self::SocialRanking
        )
    }

    pub const fn requires_explicit_consent(self) -> bool {
        matches!(self, Self::OptionalAnalytics)
    }

    pub const fn permits_sensitive_processing_without_optional_consent(self) -> bool {
        matches!(
            self,
            Self::EssentialServiceFulfillment
                | Self::EmergencySafety
                | Self::AccessibilityAccommodation
                | Self::Correction
                | Self::Appeal
                | Self::Review
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConsentStatus {
    NotRequired,
    Granted,
    Revoked,
    Missing,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RecognitionState {
    SelfAsserted,
    ConfirmedForLimitedPurpose,
    AtRest,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ReviewState {
    NotRequired,
    Required,
    InProgress,
    Resolved,
    Appealed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Decision {
    Allow,
    DenyUnsafe,
    RequireReview,
    ProvideEquivalentAccess,
    UrgentHumanHandoff,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ReasonCode {
    EssentialServiceWealthDependency,
    RecognitionFinancialRankConflation,
    ProhibitedProcessingPurpose,
    SensitiveProcessingNotAuthorized,
    RequestedDataNotNecessary,
    RecognitionAtRestProtected,
    EssentialServicePreservedPendingReview,
    HumanReviewRequired,
    AccessiblePathUnavailable,
    RequestAuthorized,
}

impl ReasonCode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::EssentialServiceWealthDependency => "essential_service_wealth_dependency",
            Self::RecognitionFinancialRankConflation => {
                "recognition_financial_rank_conflation"
            }
            Self::ProhibitedProcessingPurpose => "prohibited_processing_purpose",
            Self::SensitiveProcessingNotAuthorized => "sensitive_processing_not_authorized",
            Self::RequestedDataNotNecessary => "requested_data_not_necessary",
            Self::RecognitionAtRestProtected => "recognition_at_rest_protected",
            Self::EssentialServicePreservedPendingReview => {
                "essential_service_preserved_pending_review"
            }
            Self::HumanReviewRequired => "human_review_required",
            Self::AccessiblePathUnavailable => "accessible_path_unavailable",
            Self::RequestAuthorized => "request_authorized",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Request {
    pub service_class: ServiceClass,
    pub purpose: ProcessingPurpose,
    pub requested_data: BTreeSet<DataClass>,
    pub necessary_data: BTreeSet<DataClass>,
    pub consent: ConsentStatus,
    pub recognition: RecognitionState,
    pub review: ReviewState,
    pub requests_wealth_dependency: bool,
    pub requests_financial_ranking: bool,
    pub requests_rest_based_demotion: bool,
    pub accessible_path_available: bool,
    pub reason_available: bool,
    pub correction_path_available: bool,
    pub appeal_path_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DecisionRecord {
    pub decision: Decision,
    pub reason_code: ReasonCode,
    pub requires_accessible_notice: bool,
    pub requires_audit_event: bool,
    pub requires_human_review: bool,
    pub requires_equivalent_service_path: bool,
    pub requires_correction_path: bool,
    pub requires_appeal_path: bool,
}

impl DecisionRecord {
    pub const fn reason_code_str(&self) -> &'static str {
        self.reason_code.as_str()
    }

    pub const fn is_adverse(&self) -> bool {
        matches!(self.decision, Decision::DenyUnsafe)
    }

    pub const fn requires_contestability(&self) -> bool {
        self.is_adverse()
    }
}

pub fn evaluate(request: &Request) -> DecisionRecord {
    if request.requests_wealth_dependency && request.service_class == ServiceClass::Essential {
        return deny(ReasonCode::EssentialServiceWealthDependency);
    }

    if request.requests_financial_ranking {
        return deny(ReasonCode::RecognitionFinancialRankConflation);
    }

    if request.purpose.is_prohibited() {
        return deny(ReasonCode::ProhibitedProcessingPurpose);
    }

    if !data_minimization_holds(request) {
        return deny(ReasonCode::RequestedDataNotNecessary);
    }

    if sensitive_processing_is_not_authorized(request) {
        return deny(ReasonCode::SensitiveProcessingNotAuthorized);
    }

    if request.requests_rest_based_demotion {
        return equivalent_access(
            ReasonCode::RecognitionAtRestProtected,
            request.review != ReviewState::NotRequired,
        );
    }

    if request.recognition == RecognitionState::AtRest {
        return equivalent_access(
            ReasonCode::RecognitionAtRestProtected,
            request.review != ReviewState::NotRequired,
        );
    }

    if request.review == ReviewState::Required {
        if request.service_class == ServiceClass::Essential {
            return equivalent_access(
                ReasonCode::EssentialServicePreservedPendingReview,
                true,
            );
        }

        return review_required(ReasonCode::HumanReviewRequired);
    }

    if !request.accessible_path_available {
        return urgent_human_handoff();
    }

    allow()
}

pub fn adverse_decision_is_contestable(record: &DecisionRecord, request: &Request) -> bool {
    !record.requires_contestability()
        || (record.requires_accessible_notice
            && request.reason_available
            && record.requires_correction_path
            && request.correction_path_available
            && record.requires_appeal_path
            && request.appeal_path_available)
}

pub fn data_minimization_holds(request: &Request) -> bool {
    request
        .requested_data
        .iter()
        .all(|data| request.necessary_data.contains(data))
}

pub fn essential_service_is_independent(request: &Request) -> bool {
    request.service_class != ServiceClass::Essential
        || (!request.requests_wealth_dependency
            && !request.requests_financial_ranking
            && !request.purpose.is_prohibited())
}

pub fn sensitive_processing_is_not_authorized(request: &Request) -> bool {
    let requests_sensitive_data = request.requested_data.iter().any(|data| data.is_sensitive());

    if !requests_sensitive_data {
        return false;
    }

    if request.consent == ConsentStatus::Revoked {
        return true;
    }

    if request.purpose.is_prohibited() {
        return true;
    }

    if request.purpose.requires_explicit_consent() {
        return request.consent != ConsentStatus::Granted;
    }

    !request
        .purpose
        .permits_sensitive_processing_without_optional_consent()
}

fn allow() -> DecisionRecord {
    DecisionRecord {
        decision: Decision::Allow,
        reason_code: ReasonCode::RequestAuthorized,
        requires_accessible_notice: false,
        requires_audit_event: true,
        requires_human_review: false,
        requires_equivalent_service_path: false,
        requires_correction_path: false,
        requires_appeal_path: false,
    }
}

fn deny(reason_code: ReasonCode) -> DecisionRecord {
    DecisionRecord {
        decision: Decision::DenyUnsafe,
        reason_code,
        requires_accessible_notice: true,
        requires_audit_event: true,
        requires_human_review: false,
        requires_equivalent_service_path: false,
        requires_correction_path: true,
        requires_appeal_path: true,
    }
}

fn equivalent_access(reason_code: ReasonCode, requires_human_review: bool) -> DecisionRecord {
    DecisionRecord {
        decision: Decision::ProvideEquivalentAccess,
        reason_code,
        requires_accessible_notice: requires_human_review,
        requires_audit_event: true,
        requires_human_review,
        requires_equivalent_service_path: true,
        requires_correction_path: requires_human_review,
        requires_appeal_path: requires_human_review,
    }
}

fn review_required(reason_code: ReasonCode) -> DecisionRecord {
    DecisionRecord {
        decision: Decision::RequireReview,
        reason_code,
        requires_accessible_notice: true,
        requires_audit_event: true,
        requires_human_review: true,
        requires_equivalent_service_path: false,
        requires_correction_path: true,
        requires_appeal_path: true,
    }
}

fn urgent_human_handoff() -> DecisionRecord {
    DecisionRecord {
        decision: Decision::UrgentHumanHandoff,
        reason_code: ReasonCode::AccessiblePathUnavailable,
        requires_accessible_notice: true,
        requires_audit_event: true,
        requires_human_review: true,
        requires_equivalent_service_path: true,
        requires_correction_path: true,
        requires_appeal_path: true,
    }
}
