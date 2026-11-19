use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::UnitInterval;
use crate::error::{PopmathError, PopmathResult};

/// High-level reason for conducting a scenario.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PurposeCategory {
    /// Aggregate mobility or transit planning.
    MobilityPlanning,
    /// Construction, materials, crews, or staging analysis.
    ConstructionLogistics,
    /// Water supply, treatment, conservation, or resilience planning.
    WaterResilience,
    /// Energy demand, storage, or critical-service resilience planning.
    EnergyResilience,
    /// Ecological restoration or environmental accounting.
    EcologicalRestoration,
    /// Capacity analysis for public services.
    PublicServiceCapacity,
    /// Lifecycle-cost or capital-planning analysis.
    CapitalPlanning,
    /// Continuity and service-resilience planning.
    ContinuityPlanning,
    /// Public-interest research and education.
    Research,
}

/// Purpose declaration for a scenario.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Purpose {
    category: PurposeCategory,
    statement: String,
}

impl Purpose {
    /// Creates a non-empty purpose declaration.
    pub fn new(category: PurposeCategory, statement: impl Into<String>) -> PopmathResult<Self> {
        let statement = statement.into();

        if statement.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "purpose_statement",
            });
        }

        Ok(Self {
            category,
            statement,
        })
    }

    /// Returns the purpose category.
    #[must_use]
    pub const fn category(&self) -> PurposeCategory {
        self.category
    }

    /// Returns the plain-language purpose statement.
    #[must_use]
    pub fn statement(&self) -> &str {
        &self.statement
    }
}

/// Permitted downstream interpretation of a result.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PermittedUse {
    /// Scenario comparison only.
    AggregateScenarioComparison,
    /// Public-interest research.
    Research,
    /// Infrastructure planning support with required review.
    PlanningSupport,
    /// Ecological or resource measurement reporting.
    EnvironmentalMeasurement,
}

/// Boundary on what a calculation may represent.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DecisionBoundary {
    /// The result is analysis only.
    AnalysisOnly,
    /// The result supports planning, subject to review.
    PlanningSupport,
    /// The result is not allowed to support a decision.
    NotPermittedForDecision,
}

/// Human and community review level required for a result.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum ReviewRequirement {
    /// No extra review beyond normal engineering review.
    Standard,
    /// Technical review is required.
    Technical,
    /// Accessibility review is required.
    Accessibility,
    /// Ecological review is required.
    Ecological,
    /// Community and technical review are required.
    Community,
    /// A result is blocked until an authorized review is recorded.
    Blocked,
}

/// Policy associated with scenario data and results.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DataUsePolicy {
    permitted_use: PermittedUse,
    decision_boundary: DecisionBoundary,
    review_requirement: ReviewRequirement,
    person_level_profiling_prohibited: bool,
    hidden_scoring_prohibited: bool,
}

impl DataUsePolicy {
    /// Creates a strict default policy for aggregate civic computation.
    #[must_use]
    pub const fn aggregate_public_interest(
        permitted_use: PermittedUse,
        decision_boundary: DecisionBoundary,
        review_requirement: ReviewRequirement,
    ) -> Self {
        Self {
            permitted_use,
            decision_boundary,
            review_requirement,
            person_level_profiling_prohibited: true,
            hidden_scoring_prohibited: true,
        }
    }

    /// Validates the policy before calculation.
    pub fn authorize(&self) -> PopmathResult<()> {
        if self.decision_boundary == DecisionBoundary::NotPermittedForDecision {
            return Err(PopmathError::ProhibitedUse);
        }

        if self.review_requirement == ReviewRequirement::Blocked {
            return Err(PopmathError::GovernanceReviewRequired);
        }

        Ok(())
    }

    /// Returns the downstream use category.
    #[must_use]
    pub const fn permitted_use(&self) -> PermittedUse {
        self.permitted_use
    }

    /// Returns the decision boundary.
    #[must_use]
    pub const fn decision_boundary(&self) -> DecisionBoundary {
        self.decision_boundary
    }

    /// Returns the review requirement.
    #[must_use]
    pub const fn review_requirement(&self) -> ReviewRequirement {
        self.review_requirement
    }

    /// Returns whether person-level profiling is prohibited.
    #[must_use]
    pub const fn person_level_profiling_prohibited(&self) -> bool {
        self.person_level_profiling_prohibited
    }

    /// Returns whether hidden scoring is prohibited.
    #[must_use]
    pub const fn hidden_scoring_prohibited(&self) -> bool {
        self.hidden_scoring_prohibited
    }
}

/// Result of applying governance checks to a scenario.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GovernanceAssessment {
    /// Calculation is allowed with documented review requirement.
    Authorized,
    /// Calculation may continue, but the result requires review.
    ReviewRequired,
    /// Calculation is prohibited.
    Rejected,
}

impl GovernanceAssessment {
    /// Evaluates a policy into an externally visible status.
    #[must_use]
    pub const fn from_policy(policy: &DataUsePolicy) -> Self {
        if policy.decision_boundary == DecisionBoundary::NotPermittedForDecision {
            Self::Rejected
        } else if policy.review_requirement == ReviewRequirement::Blocked {
            Self::ReviewRequired
        } else {
            Self::Authorized
        }
    }

    /// Combines an existing governance assessment with an anti-discrimination assessment.
    #[must_use]
    pub const fn with_anti_discrimination(
        self,
        anti_discrimination_status: AntiDiscriminationStatus,
    ) -> Self {
        match (self, anti_discrimination_status) {
            (Self::Rejected, _) | (_, AntiDiscriminationStatus::Blocked) => Self::Rejected,
            (Self::ReviewRequired, _) | (_, AntiDiscriminationStatus::ReviewRequired) => {
                Self::ReviewRequired
            }
            (Self::Authorized, AntiDiscriminationStatus::Aligned) => Self::Authorized,
        }
    }
}

/// Evaluation status for equal and continuous access conditions in a scenario.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AntiDiscriminationStatus {
    /// Essential access requirements have documented primary or fallback paths.
    Aligned,
    /// Essential access requirements need more evidence or an explicit mitigation record.
    ReviewRequired,
    /// An essential requirement has no declared primary or independent fallback path.
    Blocked,
}

/// Importance level for a declared service or infrastructure requirement.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AccessRequirementClass {
    /// A requirement needed for meaningful access to an essential service.
    Essential,
    /// A material requirement whose absence should be recorded and evaluated.
    Important,
    /// A beneficial requirement that is not required for baseline service access.
    Optional,
}

/// Evidence-backed equivalence check for one declared access requirement.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AccessEquivalenceCheck {
    requirement_name: String,
    class: AccessRequirementClass,
    primary_path_available: bool,
    independent_fallback_available: bool,
    evidence_complete: bool,
    explanation: String,
}

impl AccessEquivalenceCheck {
    /// Creates a check with a non-empty requirement name and explanation.
    pub fn new(
        requirement_name: impl Into<String>,
        class: AccessRequirementClass,
        primary_path_available: bool,
        independent_fallback_available: bool,
        evidence_complete: bool,
        explanation: impl Into<String>,
    ) -> PopmathResult<Self> {
        let requirement_name = requirement_name.into();
        let explanation = explanation.into();

        if requirement_name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "access_requirement_name",
            });
        }

        if explanation.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "access_requirement_explanation",
            });
        }

        Ok(Self {
            requirement_name,
            class,
            primary_path_available,
            independent_fallback_available,
            evidence_complete,
            explanation,
        })
    }

    /// Returns the requirement name.
    #[must_use]
    pub fn requirement_name(&self) -> &str {
        &self.requirement_name
    }

    /// Returns the declared requirement class.
    #[must_use]
    pub const fn class(&self) -> AccessRequirementClass {
        self.class
    }

    /// Returns whether a primary access path is available.
    #[must_use]
    pub const fn primary_path_available(&self) -> bool {
        self.primary_path_available
    }

    /// Returns whether an independent fallback path is available.
    #[must_use]
    pub const fn independent_fallback_available(&self) -> bool {
        self.independent_fallback_available
    }

    /// Returns whether the path evidence is complete.
    #[must_use]
    pub const fn evidence_complete(&self) -> bool {
        self.evidence_complete
    }

    /// Returns the explanation associated with this check.
    #[must_use]
    pub fn explanation(&self) -> &str {
        &self.explanation
    }

    /// Returns whether the requirement has a primary or independent fallback path.
    #[must_use]
    pub const fn has_equivalent_access(&self) -> bool {
        self.primary_path_available || self.independent_fallback_available
    }
}

/// Aggregate anti-discrimination evaluation for declared scenario requirements.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AntiDiscriminationAssessment {
    status: AntiDiscriminationStatus,
    access_equivalence_ratio: UnitInterval,
    review_reasons: Vec<String>,
    blocked_reasons: Vec<String>,
}

impl AntiDiscriminationAssessment {
    /// Returns the overall equal-access assessment status.
    #[must_use]
    pub const fn status(&self) -> AntiDiscriminationStatus {
        self.status
    }

    /// Returns the fraction of essential requirements with an available primary or fallback path.
    #[must_use]
    pub const fn access_equivalence_ratio(&self) -> UnitInterval {
        self.access_equivalence_ratio
    }

    /// Returns recorded reasons requiring review.
    #[must_use]
    pub fn review_reasons(&self) -> &[String] {
        &self.review_reasons
    }

    /// Returns recorded reasons that block a decision-ready result.
    #[must_use]
    pub fn blocked_reasons(&self) -> &[String] {
        &self.blocked_reasons
    }
}

/// Evaluates whether essential scenario requirements have equivalent access paths and evidence.
#[must_use]
pub fn assess_anti_discrimination(
    checks: &[AccessEquivalenceCheck],
) -> AntiDiscriminationAssessment {
    let essential_count = checks
        .iter()
        .filter(|check| check.class == AccessRequirementClass::Essential)
        .count();

    if essential_count == 0 {
        return AntiDiscriminationAssessment {
            status: AntiDiscriminationStatus::ReviewRequired,
            access_equivalence_ratio: unit_interval_zero(),
            review_reasons: vec![String::from(
                "No essential access equivalence checks were declared for this scenario.",
            )],
            blocked_reasons: Vec::new(),
        };
    }

    let mut satisfied_count = 0usize;
    let mut review_reasons = Vec::new();
    let mut blocked_reasons = Vec::new();

    for check in checks {
        if check.class != AccessRequirementClass::Essential {
            continue;
        }

        if check.has_equivalent_access() {
            satisfied_count += 1;
        } else {
            blocked_reasons.push(format!(
                "Essential requirement '{}' has neither a primary access path nor an independent fallback.",
                check.requirement_name()
            ));
        }

        if !check.evidence_complete() {
            review_reasons.push(format!(
                "Essential requirement '{}' lacks complete evidence for its declared access pathway.",
                check.requirement_name()
            ));
        }
    }

    let access_equivalence_ratio = UnitInterval::new(
        satisfied_count as f64 / essential_count as f64,
    )
    .expect("essential access equivalence ratio is bounded by construction");

    let status = if !blocked_reasons.is_empty() {
        AntiDiscriminationStatus::Blocked
    } else if !review_reasons.is_empty() {
        AntiDiscriminationStatus::ReviewRequired
    } else {
        AntiDiscriminationStatus::Aligned
    };

    AntiDiscriminationAssessment {
        status,
        access_equivalence_ratio,
        review_reasons,
        blocked_reasons,
    }
}

const fn unit_interval_zero() -> UnitInterval {
    match UnitInterval::new(0.0) {
        Ok(value) => value,
        Err(_) => unreachable!(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn essential_check(
        primary_path_available: bool,
        independent_fallback_available: bool,
        evidence_complete: bool,
    ) -> AccessEquivalenceCheck {
        AccessEquivalenceCheck::new(
            "Continuous service pathway",
            AccessRequirementClass::Essential,
            primary_path_available,
            independent_fallback_available,
            evidence_complete,
            "Synthetic governance test fixture.",
        )
        .expect("valid test check")
    }

    #[test]
    fn purpose_requires_a_non_empty_statement() {
        assert_eq!(
            Purpose::new(PurposeCategory::Research, "  "),
            Err(PopmathError::InvalidScenario {
                field: "purpose_statement",
            })
        );
    }

    #[test]
    fn blocked_policy_requires_review() {
        let policy = DataUsePolicy::aggregate_public_interest(
            PermittedUse::PlanningSupport,
            DecisionBoundary::PlanningSupport,
            ReviewRequirement::Blocked,
        );

        assert_eq!(
            policy.authorize(),
            Err(PopmathError::GovernanceReviewRequired)
        );
        assert_eq!(
            GovernanceAssessment::from_policy(&policy),
            GovernanceAssessment::ReviewRequired
        );
    }

    #[test]
    fn prohibited_decision_boundary_is_rejected() {
        let policy = DataUsePolicy::aggregate_public_interest(
            PermittedUse::AggregateScenarioComparison,
            DecisionBoundary::NotPermittedForDecision,
            ReviewRequirement::Standard,
        );

        assert_eq!(policy.authorize(), Err(PopmathError::ProhibitedUse));
        assert_eq!(
            GovernanceAssessment::from_policy(&policy),
            GovernanceAssessment::Rejected
        );
    }

    #[test]
    fn complete_primary_or_fallback_paths_are_aligned() {
        let assessment = assess_anti_discrimination(&[
            essential_check(true, false, true),
            essential_check(false, true, true),
        ]);

        assert_eq!(assessment.status(), AntiDiscriminationStatus::Aligned);
        assert_eq!(assessment.access_equivalence_ratio().value(), 1.0);
        assert!(assessment.review_reasons().is_empty());
        assert!(assessment.blocked_reasons().is_empty());
    }

    #[test]
    fn incomplete_evidence_requires_review() {
        let assessment = assess_anti_discrimination(&[
            essential_check(true, false, false),
        ]);

        assert_eq!(
            assessment.status(),
            AntiDiscriminationStatus::ReviewRequired
        );
        assert_eq!(assessment.access_equivalence_ratio().value(), 1.0);
        assert_eq!(assessment.review_reasons().len(), 1);
        assert!(assessment.blocked_reasons().is_empty());
    }

    #[test]
    fn missing_primary_and_fallback_path_blocks_assessment() {
        let assessment = assess_anti_discrimination(&[
            essential_check(false, false, true),
        ]);

        assert_eq!(assessment.status(), AntiDiscriminationStatus::Blocked);
        assert_eq!(assessment.access_equivalence_ratio().value(), 0.0);
        assert!(assessment.review_reasons().is_empty());
        assert_eq!(assessment.blocked_reasons().len(), 1);
    }

    #[test]
    fn no_essential_checks_requires_review() {
        let optional_check = AccessEquivalenceCheck::new(
            "Supplemental public information route",
            AccessRequirementClass::Optional,
            true,
            false,
            true,
            "A supplemental local route is available.",
        )
        .expect("valid optional check");

        let assessment = assess_anti_discrimination(&[optional_check]);

        assert_eq!(
            assessment.status(),
            AntiDiscriminationStatus::ReviewRequired
        );
        assert_eq!(assessment.access_equivalence_ratio().value(), 0.0);
        assert_eq!(assessment.review_reasons().len(), 1);
    }

    #[test]
    fn blocked_status_has_precedence_over_review_status() {
        let assessment = assess_anti_discrimination(&[
            essential_check(false, false, false),
        ]);

        assert_eq!(assessment.status(), AntiDiscriminationStatus::Blocked);
        assert_eq!(assessment.review_reasons().len(), 1);
        assert_eq!(assessment.blocked_reasons().len(), 1);

        assert_eq!(
            GovernanceAssessment::Authorized.with_anti_discrimination(
                assessment.status(),
            ),
            GovernanceAssessment::Rejected
        );
    }

    #[test]
    fn governance_assessment_preserves_existing_review_requirement() {
        assert_eq!(
            GovernanceAssessment::ReviewRequired.with_anti_discrimination(
                AntiDiscriminationStatus::Aligned,
            ),
            GovernanceAssessment::ReviewRequired
        );
    }
}
