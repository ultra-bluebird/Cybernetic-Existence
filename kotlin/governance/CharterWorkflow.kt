package org.augmentedhub.governance

import org.augmentedhub.calculators.EnvironmentalReferenceCalculators
import org.augmentedhub.explanations.AccessibleExplanationFactory
import org.augmentedhub.explanations.CanonicalAdvisoryResult
import org.augmentedhub.explanations.ExplanationAudience

enum class CharterWorkflowDecisionState {
    APPROVED_FOR_ADVISORY_USE,
    NEEDS_REVIEW,
    BLOCKED,
    INSUFFICIENT_EVIDENCE,
    OUT_OF_DOMAIN,
    RESTRICT_TO_SAFE_OFFLINE_MODE
}

data class CharterWorkflowResult(
    val decisionState: CharterWorkflowDecisionState,
    val knowledgeFactor: Double,
    val ecoImpactValue: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double,
    val uncertaintyScore: Double,
    val reasons: List<String>,
    val universalExplanation: String,
    val requiresHumanReview: Boolean,
    val safeOfflineMode: Boolean
)

object CharterWorkflow {
    private const val KNOWLEDGE_MINIMUM = 0.60
    private const val ECO_IMPACT_MINIMUM = 0.50
    private const val HARM_RISK_MAXIMUM = 0.45
    private const val ACCESSIBILITY_MINIMUM = 0.70
    private const val RIGHTS_ALIGNMENT_MINIMUM = 0.80
    private const val UNCERTAINTY_THRESHOLD = 0.50

    @JvmStatic
    fun execute(input: CharterPolicyInput): CharterWorkflowResult {
        val reasons = mutableListOf<String>()

        if (input.hasInsufficientEvidence()) {
            return CharterWorkflowResult(
                decisionState = CharterWorkflowDecisionState.INSUFFICIENT_EVIDENCE,
                knowledgeFactor = 0.0,
                ecoImpactValue = input.ker.ecoImpactValue,
                harmRisk = input.ker.harmRisk,
                accessibilityImpact = input.ker.accessibilityImpact,
                rightsAlignment = input.ker.rightsAlignment,
                uncertaintyScore = input.uncertainty.uncertaintyScore,
                reasons = listOf("At least one evidence quality score is zero."),
                universalExplanation = buildUniversalExplanation(
                    state = CharterWorkflowDecisionState.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("At least one evidence quality score is zero."),
                    uncertaintyScore = input.uncertainty.uncertaintyScore
                ),
                requiresHumanReview = true,
                safeOfflineMode = false
            )
        }

        val knowledgeFactor = EnvironmentalReferenceCalculators.calculateKnowledgeFactor(
            input.evidence.qualityScores,
            input.evidence.weights
        )

        val kerAssessment = org.augmentedhub.calculators.KerAssessment(
            knowledgeFactor = knowledgeFactor,
            ecoImpactValue = input.ker.ecoImpactValue,
            harmRisk = input.ker.harmRisk,
            accessibilityImpact = input.ker.accessibilityImpact,
            rightsAlignment = input.ker.rightsAlignment
        )

        val gateResult = EnvironmentalReferenceCalculators.evaluateNonCompensatoryKerGate(kerAssessment)

        if (input.ker.harmRisk > HARM_RISK_MAXIMUM) {
            reasons += "Harm risk exceeds the non-compensatory threshold."
        }

        if (input.ker.accessibilityImpact < ACCESSIBILITY_MINIMUM) {
            reasons += "Accessibility impact is below the required threshold."
        }

        if (input.ker.rightsAlignment < RIGHTS_ALIGNMENT_MINIMUM) {
            reasons += "Rights alignment is below the required threshold."
        }

        if (knowledgeFactor < KNOWLEDGE_MINIMUM) {
            reasons += "Knowledge factor is below the advisory threshold."
        }

        if (input.ker.ecoImpactValue < ECO_IMPACT_MINIMUM) {
            reasons += "Ecological impact value is below the advisory threshold."
        }

        if (input.uncertainty.uncertaintyScore > UNCERTAINTY_THRESHOLD) {
            reasons += "Uncertainty exceeds the configured threshold."
        }

        if (!input.governance.humanReviewAvailable) {
            reasons += "Human review is not available."
        }

        if (!input.governance.accessibleExplanationAvailable) {
            reasons += "Accessible explanation is not available."
        }

        if (!input.governance.appealPathAvailable) {
            reasons += "Appeal path is not available."
        }

        val offlineMode = !input.runtime.networkAvailable && !input.policyBundle.signatureValid

        if (offlineMode) {
            return CharterWorkflowResult(
                decisionState = CharterWorkflowDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE,
                knowledgeFactor = knowledgeFactor,
                ecoImpactValue = input.ker.ecoImpactValue,
                harmRisk = input.ker.harmRisk,
                accessibilityImpact = input.ker.accessibilityImpact,
                rightsAlignment = input.ker.rightsAlignment,
                uncertaintyScore = input.uncertainty.uncertaintyScore,
                reasons = listOf("A valid signed policy is not available while offline."),
                universalExplanation = buildUniversalExplanation(
                    state = CharterWorkflowDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE,
                    reasons = listOf("A valid signed policy is not available while offline."),
                    uncertaintyScore = input.uncertainty.uncertaintyScore
                ),
                requiresHumanReview = true,
                safeOfflineMode = true
            )
        }

        val blockedReasons = reasons.filter { reason ->
            reason.contains("Harm risk") ||
            reason.contains("Accessibility impact") ||
            reason.contains("Rights alignment")
        }

        if (blockedReasons.isNotEmpty()) {
            return CharterWorkflowResult(
                decisionState = CharterWorkflowDecisionState.BLOCKED,
                knowledgeFactor = knowledgeFactor,
                ecoImpactValue = input.ker.ecoImpactValue,
                harmRisk = input.ker.harmRisk,
                accessibilityImpact = input.ker.accessibilityImpact,
                rightsAlignment = input.ker.rightsAlignment,
                uncertaintyScore = input.uncertainty.uncertaintyScore,
                reasons = reasons.toList(),
                universalExplanation = buildUniversalExplanation(
                    state = CharterWorkflowDecisionState.BLOCKED,
                    reasons = reasons.toList(),
                    uncertaintyScore = input.uncertainty.uncertaintyScore
                ),
                requiresHumanReview = true,
                safeOfflineMode = false
            )
        }

        val needsReviewReasons = reasons.filter { reason ->
            reason.contains("Knowledge factor") ||
            reason.contains("Ecological impact") ||
            reason.contains("Uncertainty") ||
            reason.contains("Human review") ||
            reason.contains("Accessible explanation") ||
            reason.contains("Appeal path")
        }

        if (needsReviewReasons.isNotEmpty()) {
            return CharterWorkflowResult(
                decisionState = CharterWorkflowDecisionState.NEEDS_REVIEW,
                knowledgeFactor = knowledgeFactor,
                ecoImpactValue = input.ker.ecoImpactValue,
                harmRisk = input.ker.harmRisk,
                accessibilityImpact = input.ker.accessibilityImpact,
                rightsAlignment = input.ker.rightsAlignment,
                uncertaintyScore = input.uncertainty.uncertaintyScore,
                reasons = reasons.toList(),
                universalExplanation = buildUniversalExplanation(
                    state = CharterWorkflowDecisionState.NEEDS_REVIEW,
                    reasons = reasons.toList(),
                    uncertaintyScore = input.uncertainty.uncertaintyScore
                ),
                requiresHumanReview = true,
                safeOfflineMode = false
            )
        }

        if (!gateResult.approvedForAdvisoryUse) {
            return CharterWorkflowResult(
                decisionState = CharterWorkflowDecisionState.NEEDS_REVIEW,
                knowledgeFactor = knowledgeFactor,
                ecoImpactValue = input.ker.ecoImpactValue,
                harmRisk = input.ker.harmRisk,
                accessibilityImpact = input.ker.accessibilityImpact,
                rightsAlignment = input.ker.rightsAlignment,
                uncertaintyScore = input.uncertainty.uncertaintyScore,
                reasons = gateResult.reasons,
                universalExplanation = buildUniversalExplanation(
                    state = CharterWorkflowDecisionState.NEEDS_REVIEW,
                    reasons = gateResult.reasons,
                    uncertaintyScore = input.uncertainty.uncertaintyScore
                ),
                requiresHumanReview = true,
                safeOfflineMode = false
            )
        }

        return CharterWorkflowResult(
            decisionState = CharterWorkflowDecisionState.APPROVED_FOR_ADVISORY_USE,
            knowledgeFactor = knowledgeFactor,
            ecoImpactValue = input.ker.ecoImpactValue,
            harmRisk = input.ker.harmRisk,
            accessibilityImpact = input.ker.accessibilityImpact,
            rightsAlignment = input.ker.rightsAlignment,
            uncertaintyScore = input.uncertainty.uncertaintyScore,
            reasons = emptyList(),
            universalExplanation = buildUniversalExplanation(
                state = CharterWorkflowDecisionState.APPROVED_FOR_ADVISORY_USE,
                reasons = emptyList(),
                uncertaintyScore = input.uncertainty.uncertaintyScore
            ),
            requiresHumanReview = true,
            safeOfflineMode = false
        )
    }

    private fun buildUniversalExplanation(
        state: CharterWorkflowDecisionState,
        reasons: List<String>,
        uncertaintyScore: Double
    ): String {
        val canonicalResult = CanonicalAdvisoryResult(
            decisionState = when (state) {
                CharterWorkflowDecisionState.APPROVED_FOR_ADVISORY_USE ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.APPROVED_FOR_ADVISORY_USE
                CharterWorkflowDecisionState.NEEDS_REVIEW ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.NEEDS_REVIEW
                CharterWorkflowDecisionState.BLOCKED ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.BLOCKED
                CharterWorkflowDecisionState.INSUFFICIENT_EVIDENCE ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.INSUFFICIENT_EVIDENCE
                CharterWorkflowDecisionState.OUT_OF_DOMAIN ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.OUT_OF_DOMAIN
                CharterWorkflowDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE ->
                    org.augmentedhub.explanations.AdvisoryDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE
            },
            whatHappened = buildWhatHappened(state),
            mainReasons = reasons.ifEmpty { listOf("No issues detected.") },
            knowledgeFactor = 0.0,
            ecoImpactValue = 0.0,
            harmRisk = 0.0,
            accessibilityImpact = 0.0,
            rightsAlignment = 0.0,
            uncertaintyScore = uncertaintyScore,
            limitations = listOf("This is an advisory result only."),
            nextStep = buildNextStep(state),
            correctionPath = "accessible correction workflow",
            appealPath = "accessible appeal workflow",
            nonDigitalOptions = listOf("telephone", "postal mail", "relay service", "in-person support")
        )

        val explanation = AccessibleExplanationFactory.create(
            canonicalResult,
            ExplanationAudience.UNIVERSAL
        )

        return "${explanation.whatHappened} ${explanation.why} ${explanation.certainty} ${explanation.doesNotMean} ${explanation.nextStep} ${explanation.personOptions}"
    }

    private fun buildWhatHappened(state: CharterWorkflowDecisionState): String {
        return when (state) {
            CharterWorkflowDecisionState.APPROVED_FOR_ADVISORY_USE ->
                "The advisory result meets all charter requirements."
            CharterWorkflowDecisionState.NEEDS_REVIEW ->
                "The advisory result requires review before use."
            CharterWorkflowDecisionState.BLOCKED ->
                "The advisory result is blocked due to a safety, accessibility, or rights condition."
            CharterWorkflowDecisionState.INSUFFICIENT_EVIDENCE ->
                "The advisory result cannot be produced due to insufficient evidence."
            CharterWorkflowDecisionState.OUT_OF_DOMAIN ->
                "The input is outside the approved calculation domain."
            CharterWorkflowDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE ->
                "The system is in safe offline mode without a valid policy."
        }
    }

    private fun buildNextStep(state: CharterWorkflowDecisionState): String {
        return when (state) {
            CharterWorkflowDecisionState.APPROVED_FOR_ADVISORY_USE ->
                "Use this result as advisory information with accessible explanation and human review available."
            CharterWorkflowDecisionState.NEEDS_REVIEW ->
                "Review the evidence, accessibility, governance, and rights conditions before advisory use."
            CharterWorkflowDecisionState.BLOCKED ->
                "Address the blocking condition before any advisory use can be considered."
            CharterWorkflowDecisionState.INSUFFICIENT_EVIDENCE ->
                "Gather additional evidence with sufficient quality scores."
            CharterWorkflowDecisionState.OUT_OF_DOMAIN ->
                "Provide input within the approved calculation range."
            CharterWorkflowDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE ->
                "Local essential information remains available. Policy verification will resume when connectivity is restored."
        }
    }
}
