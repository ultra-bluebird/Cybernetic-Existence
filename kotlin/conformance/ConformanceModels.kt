package org.augmentedhub.conformance

/**
 * Evidence state enumeration for metric evidence classification.
 */
enum class EvidenceState {
    OBSERVED,
    CALCULATED,
    MODELED,
    INFERRED,
    COMMUNITY_REPORTED,
    UNVERIFIED,
    UNKNOWN,
    STALE,
    INSUFFICIENT_EVIDENCE,
    CONFLICTED
}

/**
 * Output classification for conformance decisions.
 * All outputs are advisory-only and do not authorize automated actions.
 */
enum class OutputClass {
    INFORMATIONAL_ONLY,
    ADVISORY_ONLY,
    ELIGIBLE_FOR_PLANNING_USE,
    NEEDS_REVIEW,
    INSUFFICIENT_EVIDENCE,
    CONFLICTED,
    LOCAL_ONLY,
    BLOCKED_BY_POLICY
}

/**
 * Release classification for data handling and privacy.
 */
enum class ReleaseClass {
    NEVER_RELEASE,
    LOCAL_ONLY,
    AGGREGATE_WITH_DIFFERENTIAL_PRIVACY,
    PUBLIC
}

/**
 * Automation state for safety governance.
 * These states are advisory and do not issue physical control commands.
 */
enum class AutomationState {
    BOUNDED_AUTOMATION_ELIGIBLE,
    REDUCE_AUTOMATION,
    FAIL_SAFE_MODE
}

/**
 * Review state tracking for human oversight requirements.
 */
enum class ReviewState {
    NOT_REQUIRED,
    PENDING,
    COMPLETE,
    REJECTED
}

/**
 * Evidence compatibility assessment result.
 */
enum class EvidenceCompatibility {
    COMPATIBLE,
    INCOMPATIBLE,
    UNKNOWN
}

/**
 * Immutable metric definition loaded from registry JSON.
 */
data class MetricDefinition(
    val metricName: String,
    val semanticVersion: String,
    val domain: String,
    val metricKind: String,
    val definition: String,
    val formulaVersion: String,
    val formulaExpression: String,
    val output: MetricOutputDefinition,
    val evidenceRequirements: MetricEvidenceRequirements,
    val uncertainty: MetricUncertainty,
    val review: MetricReviewRequirements,
    val governance: MetricGovernance,
    val prohibitedInterpretations: List<String>,
    val intendedDecisionContexts: List<String>,
    val nonPermittedDecisionContexts: List<String>
) {
    init {
        require(metricName.isNotBlank()) { "metric_name is required" }
        require(semanticVersion.isNotBlank()) { "semantic_version is required" }
        require(metricKind.isNotBlank()) { "metric_kind is required" }
        require(definition.isNotBlank()) { "definition is required" }
        require(formulaVersion.isNotBlank()) { "formula_version is required" }
        require(formulaExpression.isNotBlank()) { "formula_expression is required" }
    }
}

/**
 * Governance protections that must be present and true for a valid metric.
 */
data class MetricGovernance(
    val advisoryOnly: Boolean,
    val automatedActuationPermitted: Boolean,
    val automatedServiceDenialPermitted: Boolean,
    val biometricIdentificationPermitted: Boolean,
    val cyberneticStatusPenaltyPermitted: Boolean,
    val individualProfilingPermitted: Boolean,
    val optionalTelemetryRequired: Boolean,
    val continuousConnectivityRequired: Boolean,
    val gateRelationship: String
)

/**
 * Evidence requirements for a metric.
 */
data class MetricEvidenceRequirements(
    val requiredFields: List<String>,
    val missingDataBehavior: String,
    val staleDataBehavior: String,
    val zeroQualityBehavior: String,
    val refugeInventoryRequired: Boolean = false,
    val capacityEvidenceRequired: Boolean = false,
    val coolingIntensityEvidenceRequired: Boolean = false,
    val accessibilityInspectionRequired: Boolean = false,
    val accessibleTravelNetworkRequired: Boolean = false,
    val routeProfileRequired: Boolean = false,
    val accessibleNetworkEvidenceRequired: Boolean = false,
    val sharedMeasurementPeriodRequired: Boolean = false,
    val sharedSystemBoundaryRequired: Boolean = false,
    val meterCalibrationEvidenceRequired: Boolean = false,
    val maintenanceConditionEvidenceRequired: Boolean = false,
    val lifecycleBoundaryRequiredForEcologicalClaims: Boolean = false,
    val calibrationChainRequired: Boolean = false,
    val referenceStandardRequired: Boolean = false,
    val measurementUncertaintyRequired: Boolean = false,
    val modalitySpecificTolerancesRequired: Boolean = false,
    val hazardAnalysisRequired: Boolean = false,
    val safetyCaseRequired: Boolean = false,
    val perConditionMarginRequired: Boolean = false,
    val directionalOrStateExplanationRequired: Boolean = false,
    val humanProximityAssessmentRequiredForHazardousMotion: Boolean = false,
    val accessibleFallbackRequired: Boolean = false,
    val provenanceGraphRequired: Boolean = false,
    val versionHistoryRequired: Boolean = false,
    val criticalElementProfileRequired: Boolean = false
)

/**
 * Uncertainty specification for a metric.
 */
data class MetricUncertainty(
    val method: String,
    val reported: Boolean,
    val reviewThreshold: Double,
    val sources: List<String>
)

/**
 * Review requirements for a metric.
 */
data class MetricReviewRequirements(
    val humanReviewRequired: Boolean,
    val accessibleExplanationRequired: Boolean,
    val appealPathRequired: Boolean,
    val nonDigitalEscalationRequired: Boolean,
    val communityReviewRequiredForLambdaChanges: Boolean = false,
    val communityReviewRequiredForLReviewChanges: Boolean = false,
    val maxMinFairnessRequiredForInvestmentPrioritization: Boolean = false,
    val lifecycleReviewRequiredForNetPositiveEcologicalClaim: Boolean = false,
    val communityReviewRequiredForEroiThresholdChanges: Boolean = false,
    val modalityExpertReviewRequiredForToleranceChanges: Boolean = false,
    val hazardExpertReviewRequiredForBoundaryChanges: Boolean = false,
    val communityReviewRequiredForPublicSpaceAutomationChanges: Boolean = false,
    val accessibleServiceContinuityRequiredDuringProtectiveState: Boolean = false,
    val communityReviewRequiredForWeightProfileChanges: Boolean = false,
    val crossDomainReviewRequiredForCrossDomainProfileChanges: Boolean = false,
    val infrastructureExpertReviewRequiredForLambdaBaseChanges: Boolean = false,
    val communityReviewRequiredForInspectionValidityChanges: Boolean = false,
    val maintenancePriorityMustNotBeUsedAsNeglectJustification: Boolean = false
)

/**
 * Output definition for a metric.
 */
data class MetricOutputDefinition(
    val unit: String,
    val minimum: Double,
    val maximum: Double,
    val classification: String,
    val scenarioRequired: Boolean = false,
    val intervalReported: Boolean = false,
    val rawRatioReported: Boolean = false,
    val conversionModelResidualReported: Boolean = false,
    val routeProfileRequired: Boolean = false,
    val discontinuityLengthReported: Boolean = false,
    val estimatedConditionReported: Boolean = false,
    val inspectionFreshnessReported: Boolean = false,
    val compositeQualityReported: Boolean = false,
    val inspectionAgeReported: Boolean = false,
    val uncertaintyIntervalReported: Boolean = false,
    val maintenancePrioritySignalReported: Boolean = false,
    val componentScoresReported: Boolean = false,
    val weightProfileReported: Boolean = false,
    val criticalElementStatusReported: Boolean = false,
    val purposeProfileReported: Boolean = false,
    val provenanceGraphReferenceReported: Boolean = false,
    val individualComponentErrorsReported: Boolean = false,
    val directionalOffsetsReported: Boolean = false,
    val modalityRequired: Boolean = false,
    val measurementPurposeRequired: Boolean = false,
    val rawMarginReported: Boolean = false,
    val protectedMarginReported: Boolean = false,
    val perConditionMarginsReported: Boolean = false,
    val perConditionUncertaintyReported: Boolean = false,
    val perConditionSeverityReported: Boolean = false,
    val humanProximityStateReported: Boolean = false,
    val protectiveActionReported: Boolean = false
)
