use alloc::string::{String, ToString};
use alloc::vec::Vec;

use crate::bounds::UnitInterval;
use crate::governance::{
    AntiDiscriminationStatus, GovernanceAssessment, ReviewRequirement,
};
use crate::provenance_chain::ProvenanceChainSummary;
use crate::scenario::{Assumption, Scenario};

#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub enum ValidationStatus {
    Validated,
    ValidatedWithWarnings,
    ReviewRequired,
    Infeasible,
    InsufficientData,
    Rejected,
}

impl ValidationStatus {
    #[must_use]
    pub const fn with_governance(self, governance: GovernanceAssessment) -> Self {
        match (self, governance) {
            (Self::Rejected, _) | (_, GovernanceAssessment::Rejected) => Self::Rejected,
            (Self::Infeasible, _) => Self::Infeasible,
            (Self::InsufficientData, _) => Self::InsufficientData,
            (Self::ReviewRequired, _) | (_, GovernanceAssessment::ReviewRequired) => {
                Self::ReviewRequired
            }
            (Self::ValidatedWithWarnings, GovernanceAssessment::Authorized) => {
                Self::ValidatedWithWarnings
            }
            (Self::Validated, GovernanceAssessment::Authorized) => Self::Validated,
        }
    }

    #[must_use]
    pub const fn with_anti_discrimination(
        self,
        anti_discrimination: AntiDiscriminationStatus,
    ) -> Self {
        match (self, anti_discrimination) {
            (Self::Rejected, _) | (_, AntiDiscriminationStatus::Blocked) => {
                Self::Rejected
            }
            (Self::Infeasible, _) => Self::Infeasible,
            (Self::InsufficientData, _) => Self::InsufficientData,
            (Self::ReviewRequired, _) | (_, AntiDiscriminationStatus::ReviewRequired) => {
                Self::ReviewRequired
            }
            (Self::ValidatedWithWarnings, AntiDiscriminationStatus::Aligned) => {
                Self::ValidatedWithWarnings
            }
            (Self::Validated, AntiDiscriminationStatus::Aligned) => Self::Validated,
        }
    }

    #[must_use]
    pub const fn from_governance(governance: GovernanceAssessment) -> Self {
        match governance {
            GovernanceAssessment::Authorized => Self::Validated,
            GovernanceAssessment::ReviewRequired => Self::ReviewRequired,
            GovernanceAssessment::Rejected => Self::Rejected,
        }
    }

    #[must_use]
    pub const fn from_anti_discrimination(
        anti_discrimination: AntiDiscriminationStatus,
    ) -> Self {
        match anti_discrimination {
            AntiDiscriminationStatus::Aligned => Self::Validated,
            AntiDiscriminationStatus::ReviewRequired => Self::ReviewRequired,
            AntiDiscriminationStatus::Blocked => Self::Rejected,
        }
    }

    #[must_use]
    pub const fn is_decision_ready(self) -> bool {
        matches!(self, Self::Validated | Self::ValidatedWithWarnings)
    }

    #[must_use]
    pub const fn requires_review(self) -> bool {
        matches!(
            self,
            Self::ReviewRequired
                | Self::Infeasible
                | Self::InsufficientData
                | Self::Rejected
        )
    }

    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Validated => "Validated",
            Self::ValidatedWithWarnings => "ValidatedWithWarnings",
            Self::ReviewRequired => "ReviewRequired",
            Self::Infeasible => "Infeasible",
            Self::InsufficientData => "InsufficientData",
            Self::Rejected => "Rejected",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct ResultMetrics {
    knowledge_factor: UnitInterval,
    eco_impact_value: UnitInterval,
    harm_risk: UnitInterval,
    accessibility_impact: UnitInterval,
    rights_alignment: UnitInterval,
    social_acceptance_factor: UnitInterval,
}

impl ResultMetrics {
    #[must_use]
    pub const fn new(
        knowledge_factor: UnitInterval,
        eco_impact_value: UnitInterval,
        harm_risk: UnitInterval,
        accessibility_impact: UnitInterval,
        rights_alignment: UnitInterval,
        social_acceptance_factor: UnitInterval,
    ) -> Self {
        Self {
            knowledge_factor,
            eco_impact_value,
            harm_risk,
            accessibility_impact,
            rights_alignment,
            social_acceptance_factor,
        }
    }

    #[must_use]
    pub const fn knowledge_factor(self) -> UnitInterval {
        self.knowledge_factor
    }

    #[must_use]
    pub const fn eco_impact_value(self) -> UnitInterval {
        self.eco_impact_value
    }

    #[must_use]
    pub const fn harm_risk(self) -> UnitInterval {
        self.harm_risk
    }

    #[must_use]
    pub const fn accessibility_impact(self) -> UnitInterval {
        self.accessibility_impact
    }

    #[must_use]
    pub const fn rights_alignment(self) -> UnitInterval {
        self.rights_alignment
    }

    #[must_use]
    pub const fn social_acceptance_factor(self) -> UnitInterval {
        self.social_acceptance_factor
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(transparent))]
pub struct ReproducibilityDigest(String);

impl ReproducibilityDigest {
    #[must_use]
    #[cfg(feature = "sha2")]
    pub fn from_canonical_text(value: &str) -> Self {
        use core::fmt::Write;
        use sha2::{Digest, Sha256};

        let digest = Sha256::digest(value.as_bytes());
        let mut output = String::with_capacity(digest.len() * 2);

        for byte in digest {
            let _ = write!(output, "{byte:02x}");
        }

        Self(output)
    }

    #[must_use]
    #[cfg(not(feature = "sha2"))]
    pub fn from_canonical_text(value: &str) -> Self {
        let mut primary_state = 0xcbf2_9ce4_8422_2325_u64;
        let mut secondary_state = 0x8422_2325_cbf2_9ce4_u64;

        for byte in value.bytes() {
            primary_state ^= u64::from(byte);
            primary_state = primary_state.wrapping_mul(0x0000_0100_0000_01b3);

            secondary_state ^= u64::from(byte).rotate_left(1);
            secondary_state = secondary_state.wrapping_mul(0x0000_0100_0000_01b3);
        }

        Self(alloc::format!("{primary_state:016x}{secondary_state:016x}"))
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Clone, Debug, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct ResultEvidenceSummary {
    provenance_chain: ProvenanceChainSummary,
    decision_ready: bool,
}

impl ResultEvidenceSummary {
    #[must_use]
    pub fn new(provenance_chain: ProvenanceChainSummary) -> Self {
        let decision_ready = result_evidence_is_decision_ready(&provenance_chain);

        Self {
            provenance_chain,
            decision_ready,
        }
    }

    #[must_use]
    pub fn provenance_chain(&self) -> &ProvenanceChainSummary {
        &self.provenance_chain
    }

    #[must_use]
    pub const fn decision_ready(&self) -> bool {
        self.decision_ready
    }
}

#[must_use]
pub fn result_evidence_is_decision_ready(
    summary: &ProvenanceChainSummary,
) -> bool {
    summary.record_count > 0
        && summary.all_inputs_meet_required_evidence
        && summary.all_inputs_calibrated
}

#[derive(Clone, Debug)]
pub struct ResultEnvelope<T> {
    calculation_name: String,
    calculation_version: &'static str,
    scenario_name: String,
    value: T,
    validation_status: ValidationStatus,
    review_requirement: ReviewRequirement,
    metrics: ResultMetrics,
    evidence_summary: Option<ResultEvidenceSummary>,
    accessibility_summary: String,
    rights_summary: String,
    ecological_summary: String,
    warnings: Vec<String>,
    limitations: Vec<String>,
    reproducibility_digest: ReproducibilityDigest,
}

impl<T> ResultEnvelope<T> {
    #[must_use]
    pub const fn value(&self) -> &T {
        &self.value
    }

    #[must_use]
    pub const fn validation_status(&self) -> ValidationStatus {
        self.validation_status
    }

    #[must_use]
    pub const fn review_requirement(&self) -> ReviewRequirement {
        self.review_requirement
    }

    #[must_use]
    pub const fn metrics(&self) -> ResultMetrics {
        self.metrics
    }

    #[must_use]
    pub const fn reproducibility_digest(&self) -> &ReproducibilityDigest {
        &self.reproducibility_digest
    }

    #[must_use]
    pub fn evidence_summary(&self) -> Option<&ResultEvidenceSummary> {
        self.evidence_summary.as_ref()
    }

    #[must_use]
    pub fn warnings(&self) -> &[String] {
        &self.warnings
    }

    #[must_use]
    pub fn limitations(&self) -> &[String] {
        &self.limitations
    }

    #[must_use]
    pub fn accessibility_summary(&self) -> &str {
        &self.accessibility_summary
    }

    #[must_use]
    pub fn rights_summary(&self) -> &str {
        &self.rights_summary
    }

    #[must_use]
    pub fn ecological_summary(&self) -> &str {
        &self.ecological_summary
    }

    #[must_use]
    pub fn calculation_name(&self) -> &str {
        &self.calculation_name
    }

    #[must_use]
    pub fn scenario_name(&self) -> &str {
        &self.scenario_name
    }

    #[must_use]
    pub const fn calculation_version(&self) -> &'static str {
        self.calculation_version
    }

    #[must_use]
    pub fn into_value(self) -> T {
        self.value
    }

    #[must_use]
    pub fn map_value<U>(
        self,
        mapper: impl FnOnce(T) -> U,
    ) -> ResultEnvelope<U> {
        ResultEnvelope {
            calculation_name: self.calculation_name,
            calculation_version: self.calculation_version,
            scenario_name: self.scenario_name,
            value: mapper(self.value),
            validation_status: self.validation_status,
            review_requirement: self.review_requirement,
            metrics: self.metrics,
            evidence_summary: self.evidence_summary,
            accessibility_summary: self.accessibility_summary,
            rights_summary: self.rights_summary,
            ecological_summary: self.ecological_summary,
            warnings: self.warnings,
            limitations: self.limitations,
            reproducibility_digest: self.reproducibility_digest,
        }
    }
}

#[must_use]
pub fn build_result_envelope<T>(
    calculation_name: impl Into<String>,
    scenario: &Scenario,
    value: T,
    validation_status: ValidationStatus,
    metrics: ResultMetrics,
    accessibility_summary: impl Into<String>,
    rights_summary: impl Into<String>,
    ecological_summary: impl Into<String>,
    warnings: Vec<String>,
    limitations: Vec<String>,
    canonical_input_description: impl AsRef<str>,
) -> ResultEnvelope<T> {
    build_result_envelope_with_evidence(
        calculation_name,
        scenario,
        value,
        validation_status,
        metrics,
        None,
        accessibility_summary,
        rights_summary,
        ecological_summary,
        warnings,
        limitations,
        canonical_input_description,
    )
}

#[must_use]
pub fn build_result_envelope_with_evidence<T>(
    calculation_name: impl Into<String>,
    scenario: &Scenario,
    value: T,
    validation_status: ValidationStatus,
    metrics: ResultMetrics,
    evidence_summary: Option<ResultEvidenceSummary>,
    accessibility_summary: impl Into<String>,
    rights_summary: impl Into<String>,
    ecological_summary: impl Into<String>,
    warnings: Vec<String>,
    limitations: Vec<String>,
    canonical_input_description: impl AsRef<str>,
) -> ResultEnvelope<T> {
    let calculation_name = calculation_name.into();
    let accessibility_summary = accessibility_summary.into();
    let rights_summary = rights_summary.into();
    let ecological_summary = ecological_summary.into();

    let effective_validation_status = match evidence_summary.as_ref() {
        Some(summary) if !summary.decision_ready() => {
            match validation_status {
                ValidationStatus::Rejected
                | ValidationStatus::Infeasible
                | ValidationStatus::InsufficientData => validation_status,
                ValidationStatus::Validated
                | ValidationStatus::ValidatedWithWarnings
                | ValidationStatus::ReviewRequired => ValidationStatus::ReviewRequired,
            }
        }
        _ => validation_status,
    };

    let evidence_description = evidence_summary.as_ref().map_or_else(
        || String::from("evidence=none"),
        |summary| {
            let provenance = summary.provenance_chain();

            alloc::format!(
                "evidence-record-count={}|evidence-terminal-hash={}|evidence-ready={}",
                provenance.record_count,
                provenance.terminal_chain_hash,
                summary.decision_ready()
            )
        },
    );

    let canonical_description = alloc::format!(
        "result-envelope-version={}|calculation-name={}|scenario-name={}|purpose={}|input={}|{}",
        crate::RESULT_ENVELOPE_VERSION,
        calculation_name,
        scenario.name(),
        scenario.purpose().statement(),
        canonical_input_description.as_ref(),
        evidence_description,
    );

    ResultEnvelope {
        calculation_name,
        calculation_version: crate::RESULT_ENVELOPE_VERSION,
        scenario_name: scenario.name().to_owned(),
        value,
        validation_status: effective_validation_status,
        review_requirement: scenario.policy().review_requirement(),
        metrics,
        evidence_summary,
        accessibility_summary,
        rights_summary,
        ecological_summary,
        warnings,
        limitations,
        reproducibility_digest: ReproducibilityDigest::from_canonical_text(
            &canonical_description,
        ),
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct ScenarioPurpose {
    category: String,
    description: String,
}

impl ScenarioPurpose {
    #[must_use]
    pub fn new(
        category: impl Into<String>,
        description: impl Into<String>,
    ) -> Self {
        Self {
            category: category.into(),
            description: description.into(),
        }
    }

    #[must_use]
    pub fn category(&self) -> &str {
        &self.category
    }

    #[must_use]
    pub fn description(&self) -> &str {
        &self.description
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct SerializedAssumption {
    name: String,
    basis: String,
}

impl SerializedAssumption {
    #[must_use]
    pub fn new(
        name: impl Into<String>,
        basis: impl Into<String>,
    ) -> Self {
        Self {
            name: name.into(),
            basis: basis.into(),
        }
    }

    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }

    #[must_use]
    pub fn basis(&self) -> &str {
        &self.basis
    }
}

impl From<&Assumption> for SerializedAssumption {
    fn from(assumption: &Assumption) -> Self {
        Self::new(assumption.name(), assumption.basis())
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct SerializedCapabilityResult {
    kind: String,
    status: String,
    explanation: String,
}

impl SerializedCapabilityResult {
    #[must_use]
    pub fn new(
        kind: impl Into<String>,
        status: impl Into<String>,
        explanation: impl Into<String>,
    ) -> Self {
        Self {
            kind: kind.into(),
            status: status.into(),
            explanation: explanation.into(),
        }
    }

    #[must_use]
    pub fn kind(&self) -> &str {
        &self.kind
    }

    #[must_use]
    pub fn status(&self) -> &str {
        &self.status
    }

    #[must_use]
    pub fn explanation(&self) -> &str {
        &self.explanation
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct SerializedContinuity {
    overall_status: String,
    explanation: String,
    capability_results: Vec<SerializedCapabilityResult>,
}

impl SerializedContinuity {
    #[must_use]
    pub fn new(
        overall_status: impl Into<String>,
        explanation: impl Into<String>,
        capability_results: Vec<SerializedCapabilityResult>,
    ) -> Self {
        Self {
            overall_status: overall_status.into(),
            explanation: explanation.into(),
            capability_results,
        }
    }

    #[must_use]
    pub fn overall_status(&self) -> &str {
        &self.overall_status
    }

    #[must_use]
    pub fn explanation(&self) -> &str {
        &self.explanation
    }

    #[must_use]
    pub fn capability_results(&self) -> &[SerializedCapabilityResult] {
        &self.capability_results
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct SerializedReproducibility {
    digest: String,
    crate_version: String,
    random_seed: Option<u32>,
}

impl SerializedReproducibility {
    #[must_use]
    pub fn new(
        digest: impl Into<String>,
        crate_version: impl Into<String>,
        random_seed: Option<u32>,
    ) -> Self {
        Self {
            digest: digest.into(),
            crate_version: crate_version.into(),
            random_seed,
        }
    }

    #[must_use]
    pub fn digest(&self) -> &str {
        &self.digest
    }

    #[must_use]
    pub fn crate_version(&self) -> &str {
        &self.crate_version
    }

    #[must_use]
    pub const fn random_seed(&self) -> Option<u32> {
        self.random_seed
    }
}

#[derive(Clone, Debug)]
#[cfg_attr(feature = "serde", derive(Deserialize, Serialize))]
#[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct SerializableResultEnvelope<T> {
    scenario_id: String,
    purpose: ScenarioPurpose,
    assumptions: Vec<SerializedAssumption>,
    validation_status: ValidationStatus,
    continuity: Option<SerializedContinuity>,
    metrics: ResultMetrics,
    evidence_summary: Option<ResultEvidenceSummary>,
    reproducibility: SerializedReproducibility,
    result: T,
}

impl<T> SerializableResultEnvelope<T> {
    #[must_use]
    pub fn new(
        scenario_id: impl Into<String>,
        purpose: ScenarioPurpose,
        assumptions: Vec<SerializedAssumption>,
        validation_status: ValidationStatus,
        continuity: Option<SerializedContinuity>,
        metrics: ResultMetrics,
        reproducibility: SerializedReproducibility,
        result: T,
    ) -> Self {
        Self {
            scenario_id: scenario_id.into(),
            purpose,
            assumptions,
            validation_status,
            continuity,
            metrics,
            evidence_summary: None,
            reproducibility,
            result,
        }
    }

    #[must_use]
    pub fn with_evidence_summary(
        mut self,
        evidence_summary: ResultEvidenceSummary,
    ) -> Self {
        self.evidence_summary = Some(evidence_summary);
        self
    }

    #[must_use]
    pub fn scenario_id(&self) -> &str {
        &self.scenario_id
    }

    #[must_use]
    pub fn purpose(&self) -> &ScenarioPurpose {
        &self.purpose
    }

    #[must_use]
    pub fn assumptions(&self) -> &[SerializedAssumption] {
        &self.assumptions
    }

    #[must_use]
    pub const fn validation_status(&self) -> ValidationStatus {
        self.validation_status
    }

    #[must_use]
    pub fn continuity(&self) -> Option<&SerializedContinuity> {
        self.continuity.as_ref()
    }

    #[must_use]
    pub const fn metrics(&self) -> ResultMetrics {
        self.metrics
    }

    #[must_use]
    pub fn evidence_summary(&self) -> Option<&ResultEvidenceSummary> {
        self.evidence_summary.as_ref()
    }

    #[must_use]
    pub fn reproducibility(&self) -> &SerializedReproducibility {
        &self.reproducibility
    }

    #[must_use]
    pub const fn result(&self) -> &T {
        &self.result
    }

    #[must_use]
    pub fn into_result(self) -> T {
        self.result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::governance::GovernanceAssessment;

    #[test]
    fn rejected_status_has_precedence() {
        assert_eq!(
            ValidationStatus::Validated
                .with_governance(GovernanceAssessment::Rejected),
            ValidationStatus::Rejected
        );

        assert_eq!(
            ValidationStatus::Rejected
                .with_governance(GovernanceAssessment::Authorized),
            ValidationStatus::Rejected
        );
    }

    #[test]
    fn review_status_is_preserved() {
        assert_eq!(
            ValidationStatus::Validated
                .with_governance(GovernanceAssessment::ReviewRequired),
            ValidationStatus::ReviewRequired
        );

        assert_eq!(
            ValidationStatus::ReviewRequired
                .with_governance(GovernanceAssessment::Authorized),
            ValidationStatus::ReviewRequired
        );
    }

    #[test]
    fn infeasible_status_is_preserved_when_governance_is_authorized() {
        assert_eq!(
            ValidationStatus::Infeasible
                .with_governance(GovernanceAssessment::Authorized),
            ValidationStatus::Infeasible
        );
    }

    #[test]
    fn anti_discrimination_review_requires_result_review() {
        assert_eq!(
            ValidationStatus::Validated.with_anti_discrimination(
                AntiDiscriminationStatus::ReviewRequired,
            ),
            ValidationStatus::ReviewRequired
        );
    }

    #[test]
    fn anti_discrimination_blocked_rejects_result() {
        assert_eq!(
            ValidationStatus::Validated
                .with_anti_discrimination(AntiDiscriminationStatus::Blocked),
            ValidationStatus::Rejected
        );
    }

    #[test]
    fn canonical_digests_are_stable_for_equal_input() {
        let first = ReproducibilityDigest::from_canonical_text(
            "scenario=synthetic-corridor|seed=42|version=1",
        );

        let second = ReproducibilityDigest::from_canonical_text(
            "scenario=synthetic-corridor|seed=42|version=1",
        );

        assert_eq!(first, second);
        assert!(!first.as_str().is_empty());
    }

    #[test]
    fn canonical_digests_change_for_changed_input() {
        let first = ReproducibilityDigest::from_canonical_text(
            "scenario=synthetic-corridor|seed=42|version=1",
        );

        let second = ReproducibilityDigest::from_canonical_text(
            "scenario=synthetic-corridor|seed=43|version=1",
        );

        assert_ne!(first, second);
    }
}
