package org.augmentedhub.governance

import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max

enum class AdvisoryState {
    APPROVED_FOR_ADVISORY_USE,
    NEEDS_REVIEW,
    BLOCKED,
    INSUFFICIENT_EVIDENCE,
    OUT_OF_DOMAIN
}

data class EvidenceQuality(
    val measurement: Double,
    val calibration: Double,
    val provenance: Double,
    val freshness: Double,
    val coverage: Double,
    val review: Double,
    val weights: List<Double>
) {
    init {
        require(weights.size == 6) {
            "weights must contain measurement, calibration, provenance, freshness, coverage, and review weights"
        }

        require(
            listOf(
                measurement,
                calibration,
                provenance,
                freshness,
                coverage,
                review
            ).all { it.isFinite() && it in 0.0..1.0 }
        ) {
            "all evidence-quality values must be finite and within [0, 1]"
        }

        require(weights.all { it.isFinite() && it >= 0.0 }) {
            "all evidence-quality weights must be finite and non-negative"
        }

        require(weights.sum() > 0.0) {
            "at least one evidence-quality weight must be positive"
        }

        require(kotlin.math.abs(weights.sum() - 1.0) <= 0.000001) {
            "evidence-quality weights must sum to one"
        }
    }

    fun values(): List<Double> {
        return listOf(
            measurement,
            calibration,
            provenance,
            freshness,
            coverage,
            review
        )
    }
}

data class KerInput(
    val ecoImpactValue: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double
) {
    init {
        require(
            listOf(
                ecoImpactValue,
                harmRisk,
                accessibilityImpact,
                rightsAlignment
            ).all { it.isFinite() && it in 0.0..1.0 }
        ) {
            "all KER values must be finite and within [0, 1]"
        }
    }
}

data class GovernanceInput(
    val advisoryOnly: Boolean,
    val humanReviewAvailable: Boolean,
    val accessibleNoticeAvailable: Boolean,
    val accessibleExplanationAvailable: Boolean,
    val appealPathAvailable: Boolean,
    val dataMinimizationConfirmed: Boolean,
    val purposeLimitationConfirmed: Boolean,
    val retentionAndDeletionPathAvailable: Boolean,
    val requiresContinuousConnectivity: Boolean,
    val requiresOptionalTelemetry: Boolean,
    val usesBiometricIdentification: Boolean,
    val usesCyberneticStatusAsPenalty: Boolean,
    val authorizesPhysicalActuation: Boolean,
    val authorizesServiceDenial: Boolean
)

data class ReferenceKernelResult(
    val state: AdvisoryState,
    val knowledgeFactor: Double,
    val reasons: List<String>,
    val plainLanguageExplanation: String
)

object ReferenceKernel {
    private const val KNOWLEDGE_MINIMUM = 0.60
    private const val ECO_IMPACT_MINIMUM = 0.50
    private const val HARM_RISK_MAXIMUM = 0.45
    private const val ACCESSIBILITY_MINIMUM = 0.70
    private const val RIGHTS_ALIGNMENT_MINIMUM = 0.80

    @JvmStatic
    fun calculateKnowledgeFactor(quality: EvidenceQuality): Double {
        val values = quality.values()

        if (values.any { it == 0.0 }) {
            return 0.0
        }

        val logarithmicWeightedSum = values
            .zip(quality.weights)
            .sumOf { (value, weight) -> weight * ln(value) }

        return exp(logarithmicWeightedSum)
    }

    @JvmStatic
    fun evaluate(
        quality: EvidenceQuality,
        ker: KerInput,
        governance: GovernanceInput
    ): ReferenceKernelResult {
        val knowledgeFactor = calculateKnowledgeFactor(quality)
        val reasons = mutableListOf<String>()

        if (knowledgeFactor == 0.0) {
            reasons += "At least one required evidence-quality component is zero."
        }

        if (knowledgeFactor < KNOWLEDGE_MINIMUM) {
            reasons += "Knowledge factor is below the advisory threshold."
        }

        if (ker.ecoImpactValue < ECO_IMPACT_MINIMUM) {
            reasons += "Ecological impact value is below the advisory threshold."
        }

        if (ker.harmRisk > HARM_RISK_MAXIMUM) {
            reasons += "Harm risk exceeds the non-compensatory threshold."
        }

        if (ker.accessibilityImpact < ACCESSIBILITY_MINIMUM) {
            reasons += "Accessibility impact is below the required threshold."
        }

        if (ker.rightsAlignment < RIGHTS_ALIGNMENT_MINIMUM) {
            reasons += "Rights alignment is below the required threshold."
        }

        if (!governance.advisoryOnly) {
            reasons += "The result is not restricted to advisory use."
        }

        if (!governance.humanReviewAvailable) {
            reasons += "A human review path is not available."
        }

        if (!governance.accessibleNoticeAvailable) {
            reasons += "An accessible notice is not available."
        }

        if (!governance.accessibleExplanationAvailable) {
            reasons += "An accessible explanation is not available."
        }

        if (!governance.appealPathAvailable) {
            reasons += "An appeal or correction path is not available."
        }

        if (!governance.dataMinimizationConfirmed) {
            reasons += "Data minimization has not been confirmed."
        }

        if (!governance.purposeLimitationConfirmed) {
            reasons += "Purpose limitation has not been confirmed."
        }

        if (!governance.retentionAndDeletionPathAvailable) {
            reasons += "A retention and deletion path is not available."
        }

        if (governance.requiresContinuousConnectivity) {
            reasons += "Continuous connectivity is required."
        }

        if (governance.requiresOptionalTelemetry) {
            reasons += "Optional telemetry is required."
        }

        if (governance.usesBiometricIdentification) {
            reasons += "Biometric identification is used."
        }

        if (governance.usesCyberneticStatusAsPenalty) {
            reasons += "Cybernetic or assistive status is used as a penalty."
        }

        if (governance.authorizesPhysicalActuation) {
            reasons += "Physical actuation is authorized."
        }

        if (governance.authorizesServiceDenial) {
            reasons += "Service denial is authorized."
        }

        val state = classifyState(
            knowledgeFactor = knowledgeFactor,
            ker = ker,
            governance = governance,
            reasons = reasons
        )

        return ReferenceKernelResult(
            state = state,
            knowledgeFactor = knowledgeFactor,
            reasons = reasons.toList(),
            plainLanguageExplanation = explain(state, reasons)
        )
    }

    private fun classifyState(
        knowledgeFactor: Double,
        ker: KerInput,
        governance: GovernanceInput,
        reasons: List<String>
    ): AdvisoryState {
        if (
            governance.authorizesPhysicalActuation ||
            governance.authorizesServiceDenial ||
            governance.usesBiometricIdentification ||
            governance.usesCyberneticStatusAsPenalty ||
            governance.requiresOptionalTelemetry ||
            governance.requiresContinuousConnectivity
        ) {
            return AdvisoryState.BLOCKED
        }

        if (knowledgeFactor == 0.0) {
            return AdvisoryState.INSUFFICIENT_EVIDENCE
        }

        if (
            ker.harmRisk > HARM_RISK_MAXIMUM ||
            ker.accessibilityImpact < ACCESSIBILITY_MINIMUM ||
            ker.rightsAlignment < RIGHTS_ALIGNMENT_MINIMUM
        ) {
            return AdvisoryState.BLOCKED
        }

        if (
            knowledgeFactor < KNOWLEDGE_MINIMUM ||
            ker.ecoImpactValue < ECO_IMPACT_MINIMUM ||
            !governance.humanReviewAvailable ||
            !governance.accessibleNoticeAvailable ||
            !governance.accessibleExplanationAvailable ||
            !governance.appealPathAvailable ||
            !governance.dataMinimizationConfirmed ||
            !governance.purposeLimitationConfirmed ||
            !governance.retentionAndDeletionPathAvailable ||
            !governance.advisoryOnly
        ) {
            return AdvisoryState.NEEDS_REVIEW
        }

        return if (reasons.isEmpty()) {
            AdvisoryState.APPROVED_FOR_ADVISORY_USE
        } else {
            AdvisoryState.NEEDS_REVIEW
        }
    }

    private fun explain(
        state: AdvisoryState,
        reasons: List<String>
    ): String {
        return when (state) {
            AdvisoryState.APPROVED_FOR_ADVISORY_USE ->
                "This result may be used as advisory support. It remains subject to accessible explanation, human review, and appeal."

            AdvisoryState.NEEDS_REVIEW ->
                "This result needs review before advisory use. Review the evidence, accessibility, governance, and rights conditions listed in the reasons."

            AdvisoryState.BLOCKED ->
                "This result is blocked because it conflicts with a non-negotiable safety, privacy, accessibility, or rights requirement."

            AdvisoryState.INSUFFICIENT_EVIDENCE ->
                "This result cannot be used because one or more required evidence-quality components are absent or have zero quality."

            AdvisoryState.OUT_OF_DOMAIN ->
                "This result cannot be evaluated because the input is outside the approved calculation domain."
        }
    }

    @JvmStatic
    fun calculateConservativeResidual(
        predictedResidual: Double,
        residualUncertainty: Double,
        conservatismMultiplier: Double
    ): Double {
        require(predictedResidual.isFinite() && predictedResidual >= 0.0) {
            "predictedResidual must be finite and non-negative"
        }

        require(residualUncertainty.isFinite() && residualUncertainty >= 0.0) {
            "residualUncertainty must be finite and non-negative"
        }

        require(conservatismMultiplier.isFinite() && conservatismMultiplier >= 0.0) {
            "conservatismMultiplier must be finite and non-negative"
        }

        return max(
            0.0,
            predictedResidual + conservatismMultiplier * residualUncertainty
        )
    }

    @JvmStatic
    fun interventionRequiresReview(
        currentResidual: Double,
        predictedResidual: Double,
        residualUncertainty: Double,
        conservatismMultiplier: Double,
        epsilon: Double = 0.02
    ): Boolean {
        require(currentResidual.isFinite() && currentResidual >= 0.0) {
            "currentResidual must be finite and non-negative"
        }

        require(epsilon.isFinite() && epsilon >= 0.0) {
            "epsilon must be finite and non-negative"
        }

        val conservativePrediction = calculateConservativeResidual(
            predictedResidual = predictedResidual,
            residualUncertainty = residualUncertainty,
            conservatismMultiplier = conservatismMultiplier
        )

        return conservativePrediction > currentResidual + epsilon
    }
}
