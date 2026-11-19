package civic.rights

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

object AcceptanceSovereigntyAlignment {
    enum class AcceptanceStatus {
        MEASURED,
        REVIEW_REQUIRED,
        STORAGE_REJECTED
    }

    enum class PolicyDecision {
        ACCESS_PROTECTED,
        POLICY_REVIEW_REQUIRED
    }

    enum class AlignmentState {
        NOMINAL,
        ALIGNMENT_ALERT,
        INVALID_INPUT_LOCKOUT
    }

    data class AcceptanceAggregateInput(
        val reportingPeriod: String,
        val applicablePolicyCases: Long,
        val compliantPolicyCases: Long,
        val resolvedAppeals: Long,
        val eligibleAppeals: Long,
        val inclusiveServiceEvents: Long,
        val eligibleServiceEvents: Long,
        val dataCompleteness: Double,
        val containsDirectIdentifiers: Boolean,
        val containsPreciseLocation: Boolean,
        val containsBiometricData: Boolean,
        val containsNeuralData: Boolean,
        val containsContinuousSurveillance: Boolean,
        val containsPersistentDeviceIdentifiers: Boolean
    )

    data class AcceptancePatternResult(
        val status: AcceptanceStatus,
        val policyComplianceRatio: Double?,
        val appealResolutionRatio: Double?,
        val inclusionRatio: Double?,
        val acceptancePatternIndex: Double?,
        val publicStatement: String,
        val prohibitedClaims: List<String>,
        val retainedFields: List<String>,
        val knowledgeFactor: Double,
        val ecoImpactValue: Double,
        val harmRisk: Double,
        val accessibilityImpact: Double,
        val rightsAlignment: Double
    )

    data class CyberneticHostPolicyInput(
        val selfAssertedIdentityProvided: Boolean,
        val identityDisclosureVoluntary: Boolean,
        val identityVerificationRequired: Boolean,
        val serviceAccessConditionedOnDisclosure: Boolean,
        val unrelatedTelemetryRequired: Boolean,
        val nonDiscriminationCommitmentPresent: Boolean,
        val equalAccessCommitmentPresent: Boolean,
        val accessibleAppealAvailable: Boolean,
        val humanReviewAvailable: Boolean,
        val requestedAccommodationPresent: Boolean
    )

    data class CyberneticHostPolicyResult(
        val decision: PolicyDecision,
        val identityRecognitionMode: String,
        val requiredCommitments: List<String>,
        val prohibitedConditions: List<String>,
        val dataRule: String,
        val appealRule: String,
        val rationale: String
    )

    data class CorridorAlignmentInput(
        val corridorReference: String,
        val observedValue: Double,
        val referenceValue: Double,
        val referenceStandardDeviation: Double,
        val provenanceVerified: Boolean,
        val integrityVerified: Boolean,
        val rawTelemetryAttached: Boolean
    )

    data class CorridorAlignmentResult(
        val state: AlignmentState,
        val residual: Double?,
        val alertThreshold: Double,
        val safeForAutomatedReliance: Boolean,
        val requiresCalibrationReview: Boolean,
        val noActuationAuthorized: Boolean,
        val reason: String
    )

    private fun unitInterval(value: Double): Boolean =
        value.isFinite() && value >= 0.0 && value <= 1.0

    private fun nonNegative(value: Long): Boolean = value >= 0L

    private fun ratio(numerator: Long, denominator: Long): Double? {
        if (!nonNegative(numerator) || !nonNegative(denominator) || numerator > denominator || denominator == 0L) {
            return null
        }
        return numerator.toDouble() / denominator.toDouble()
    }

    private fun clamp01(value: Double): Double = max(0.0, min(1.0, value))

    /**
     * Evaluates only privacy-preserving aggregates. It does not infer
     * acceptance from individual identity, device, mobility, biometric,
     * neural, location, or surveillance records.
     */
    fun assessAcceptancePattern(input: AcceptanceAggregateInput): AcceptancePatternResult {
        val prohibitedDataPresent =
            input.containsDirectIdentifiers ||
                input.containsPreciseLocation ||
                input.containsBiometricData ||
                input.containsNeuralData ||
                input.containsContinuousSurveillance ||
                input.containsPersistentDeviceIdentifiers

        if (prohibitedDataPresent) {
            return AcceptancePatternResult(
                status = AcceptanceStatus.STORAGE_REJECTED,
                policyComplianceRatio = null,
                appealResolutionRatio = null,
                inclusionRatio = null,
                acceptancePatternIndex = null,
                publicStatement = "The acceptance-pattern record cannot be stored because prohibited personal or surveillance data is present.",
                prohibitedClaims = listOf(
                    "individual acceptance classification",
                    "identity credibility score",
                    "population-wide social acceptance conclusion"
                ),
                retainedFields = listOf(
                    "reporting_period",
                    "storage_decision",
                    "prohibited_data_category"
                ),
                knowledgeFactor = 0.0,
                ecoImpactValue = 0.0,
                harmRisk = 0.2,
                accessibilityImpact = 0.0,
                rightsAlignment = 0.98
            )
        }

        val compliance = ratio(input.compliantPolicyCases, input.applicablePolicyCases)
        val appealResolution = ratio(input.resolvedAppeals, input.eligibleAppeals)
        val inclusion = ratio(input.inclusiveServiceEvents, input.eligibleServiceEvents)

        if (
            compliance == null ||
                appealResolution == null ||
                inclusion == null ||
                !unitInterval(input.dataCompleteness) ||
                input.dataCompleteness < 0.8
        ) {
            return AcceptancePatternResult(
                status = AcceptanceStatus.REVIEW_REQUIRED,
                policyComplianceRatio = compliance,
                appealResolutionRatio = appealResolution,
                inclusionRatio = inclusion,
                acceptancePatternIndex = null,
                publicStatement = "Aggregate policy, appeal, and inclusion data requires review before a measured acceptance-pattern result is published.",
                prohibitedClaims = listOf(
                    "individual acceptance classification",
                    "identity credibility score",
                    "population-wide social acceptance conclusion"
                ),
                retainedFields = listOf(
                    "reporting_period",
                    "aggregate_case_counts",
                    "aggregate_appeal_counts",
                    "aggregate_service_counts",
                    "data_completeness"
                ),
                knowledgeFactor = if (unitInterval(input.dataCompleteness)) input.dataCompleteness else 0.0,
                ecoImpactValue = 0.0,
                harmRisk = 0.14,
                accessibilityImpact = inclusion ?: 0.0,
                rightsAlignment = 0.98
            )
        }

        val index = clamp01(
            0.45 * compliance +
                0.30 * appealResolution +
                0.25 * inclusion
        )

        return AcceptancePatternResult(
            status = AcceptanceStatus.MEASURED,
            policyComplianceRatio = compliance,
            appealResolutionRatio = appealResolution,
            inclusionRatio = inclusion,
            acceptancePatternIndex = index,
            publicStatement =
                "The aggregate acceptance-pattern index reports policy compliance, appeal resolution, and inclusive-service delivery for the stated period. It does not measure, infer, or rank any individual's identity or beliefs.",
            prohibitedClaims = listOf(
                "individual acceptance classification",
                "identity credibility score",
                "population-wide social acceptance conclusion",
                "proof of absence of discrimination"
            ),
            retainedFields = listOf(
                "reporting_period",
                "aggregate_case_counts",
                "aggregate_appeal_counts",
                "aggregate_service_counts",
                "data_completeness",
                "calculation_version"
            ),
            knowledgeFactor = input.dataCompleteness,
            ecoImpactValue = 0.72,
            harmRisk = 0.08,
            accessibilityImpact = inclusion,
            rightsAlignment = 0.99
        )
    }

    /**
     * Applies a municipal policy commitment, not a jurisdiction-specific
     * legal determination. Equal access remains available without identity
     * disclosure, verification, or unrelated telemetry.
     */
    fun assessCyberneticHostPolicy(input: CyberneticHostPolicyInput): CyberneticHostPolicyResult {
        val prohibitedConditions = listOf(
            "identity disclosure as a condition of public service",
            "external identity verification as a condition of protection",
            "unrelated telemetry as a condition of access",
            "discrimination based on actual, perceived, or self-asserted cybernetic status"
        )

        val requiredCommitments = listOf(
            "non-discrimination in municipal services and participation",
            "equal access to services, accommodations, employment, housing, education, culture, and civic processes within municipal authority",
            "voluntary self-asserted identity recognition",
            "accessible grievance, appeal, and human-review pathways",
            "privacy-preserving accommodation requests",
            "no retaliation for disclosure, non-disclosure, accommodation requests, or appeals"
        )

        if (
            input.identityVerificationRequired ||
                input.serviceAccessConditionedOnDisclosure ||
                input.unrelatedTelemetryRequired ||
                !input.nonDiscriminationCommitmentPresent ||
                !input.equalAccessCommitmentPresent ||
                !input.accessibleAppealAvailable ||
                !input.humanReviewAvailable
        ) {
            return CyberneticHostPolicyResult(
                decision = PolicyDecision.POLICY_REVIEW_REQUIRED,
                identityRecognitionMode = "ACCESS_WITHOUT_REQUIRED_DISCLOSURE",
                requiredCommitments = requiredCommitments,
                prohibitedConditions = prohibitedConditions,
                dataRule =
                    "Do not collect cybernetic-status information, augmentation details, biometric data, neural data, or unrelated telemetry to provide ordinary public services.",
                appealRule =
                    "Provide an accessible, non-retaliatory human appeal route with plain-language reasons for any adverse decision.",
                rationale =
                    "The policy configuration contains a prohibited access condition or lacks a required equal-treatment, accessibility, or review commitment."
            )
        }

        val recognitionMode =
            if (input.selfAssertedIdentityProvided && input.identityDisclosureVoluntary) {
                "VOLUNTARY_SELF_ASSERTED_RECOGNITION"
            } else {
                "ACCESS_WITHOUT_DISCLOSURE"
            }

        return CyberneticHostPolicyResult(
            decision = PolicyDecision.ACCESS_PROTECTED,
            identityRecognitionMode = recognitionMode,
            requiredCommitments = requiredCommitments,
            prohibitedConditions = prohibitedConditions,
            dataRule =
                "Store only the minimum accommodation or service information necessary for the chosen purpose. Do not store identity status unless a person voluntarily supplies it for that purpose and can access, correct, revoke, or delete it.",
            appealRule =
                "Maintain an accessible human appeal route, a written explanation standard, and a non-retaliation guarantee.",
            rationale =
                if (input.requestedAccommodationPresent) {
                    "The resident can request an accommodation without surrendering sovereignty, privacy, self-asserted identity, or equal access."
                } else {
                    "The resident retains equal access and non-discrimination protections without needing to disclose cybernetic status."
        )
    }

    /**
     * Computes r = |x_observed - x_reference| / sigma_reference.
     *
     * A residual greater than 3 produces an alignment alert. This is a
     * calibration-review signal, not a diagnosis, maintenance command,
     * physical-control authorization, or continuous-tracking mechanism.
     */
    fun assessCorridorAlignment(input: CorridorAlignmentInput): CorridorAlignmentResult {
        if (
            !input.observedValue.isFinite() ||
                !input.referenceValue.isFinite() ||
                !input.referenceStandardDeviation.isFinite() ||
                input.referenceStandardDeviation <= 0.0 ||
                !input.provenanceVerified ||
                !input.integrityVerified ||
                input.rawTelemetryAttached
        ) {
            return CorridorAlignmentResult(
                state = AlignmentState.INVALID_INPUT_LOCKOUT,
                residual = null,
                alertThreshold = 3.0,
                safeForAutomatedReliance = false,
                requiresCalibrationReview = true,
                noActuationAuthorized = true,
                reason =
                    "The alignment sample is invalid, unverified, lacks a positive reference standard deviation, or includes prohibited raw telemetry."
            )
        }

        val residual = abs(input.observedValue - input.referenceValue) /
            input.referenceStandardDeviation

        if (residual > 3.0) {
            return CorridorAlignmentResult(
                state = AlignmentState.ALIGNMENT_ALERT,
                residual = residual,
                alertThreshold = 3.0,
                safeForAutomatedReliance = false,
                requiresCalibrationReview = true,
                noActuationAuthorized = true,
                reason =
                    "The normalized residual exceeds 3.0. Preserve the evidence and request a documented calibration review before relying on this sensor for automated environmental decisions."
            )
        }

        return CorridorAlignmentResult(
            state = AlignmentState.NOMINAL,
            residual = residual,
            alertThreshold = 3.0,
            safeForAutomatedReliance = true,
            requiresCalibrationReview = false,
            noActuationAuthorized = true,
            reason =
                "The normalized residual is at or below 3.0 for this discrete calibration observation. The result remains decision support only and cannot actuate equipment."
        )
    }
}
