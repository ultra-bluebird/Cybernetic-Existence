package org.augmentedhub.explanations

enum class ExplanationAudience {
    UNIVERSAL,
    RESIDENT,
    FIELD_WORKER,
    MUNICIPAL_PLANNER,
    RESEARCHER,
    POLICY_REVIEWER
}

enum class AdvisoryDecisionState {
    APPROVED_FOR_ADVISORY_USE,
    NEEDS_REVIEW,
    BLOCKED,
    INSUFFICIENT_EVIDENCE,
    OUT_OF_DOMAIN,
    RESTRICT_TO_SAFE_OFFLINE_MODE
}

data class CanonicalAdvisoryResult(
    val decisionState: AdvisoryDecisionState,
    val whatHappened: String,
    val mainReasons: List<String>,
    val knowledgeFactor: Double,
    val ecoImpactValue: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double,
    val uncertaintyScore: Double,
    val limitations: List<String>,
    val nextStep: String,
    val correctionPath: String,
    val appealPath: String,
    val nonDigitalOptions: List<String>
) {
    init {
        require(whatHappened.isNotBlank()) {
            "whatHappened is required"
        }

        require(mainReasons.isNotEmpty()) {
            "At least one main reason is required"
        }

        require(
            listOf(
                knowledgeFactor,
                ecoImpactValue,
                harmRisk,
                accessibilityImpact,
                rightsAlignment,
                uncertaintyScore
            ).all { it.isFinite() && it in 0.0..1.0 }
        ) {
            "All scores must be finite and within [0, 1]"
        }

        require(limitations.isNotEmpty()) {
            "At least one limitation is required"
        }

        require(nextStep.isNotBlank()) {
            "nextStep is required"
        }

        require(correctionPath.isNotBlank()) {
            "correctionPath is required"
        }

        require(appealPath.isNotBlank()) {
            "appealPath is required"
        }

        require(nonDigitalOptions.isNotEmpty()) {
            "At least one non-digital option is required"
        }
    }
}

data class AccessibleExplanation(
    val audience: ExplanationAudience,
    val whatHappened: String,
    val why: String,
    val certainty: String,
    val doesNotMean: String,
    val nextStep: String,
    val personOptions: String,
    val technicalDetails: List<String>
)

object AccessibleExplanationFactory {
    @JvmStatic
    fun create(
        result: CanonicalAdvisoryResult,
        audience: ExplanationAudience
    ): AccessibleExplanation {
        val universal = universalExplanation(result)

        return when (audience) {
            ExplanationAudience.UNIVERSAL -> universal

            ExplanationAudience.RESIDENT -> universal.copy(
                audience = ExplanationAudience.RESIDENT,
                technicalDetails = listOf(
                    "You can use the correction path or appeal path without providing cybernetic, assistive-device, health, or identity information for basic access."
                )
            )

            ExplanationAudience.FIELD_WORKER -> universal.copy(
                audience = ExplanationAudience.FIELD_WORKER,
                technicalDetails = listOf(
                    "Record inspection date, method, units, calibration state, observed condition, provenance reference, and any uncertainty that affects the recommendation.",
                    "Do not replace a recorded observation with a derived metric. Preserve both records and link them through evidence lineage."
                )
            )

            ExplanationAudience.MUNICIPAL_PLANNER -> universal.copy(
                audience = ExplanationAudience.MUNICIPAL_PLANNER,
                technicalDetails = listOf(
                    "Use only aggregate planning data. Do not use individual identity, cybernetic status, disability, health, or device information as a planning input.",
                    "Prioritize non-compensatory conditions before aggregate comparison scores."
                )
            )

            ExplanationAudience.RESEARCHER -> universal.copy(
                audience = ExplanationAudience.RESEARCHER,
                technicalDetails = listOf(
                    "Knowledge factor: ${formatScore(result.knowledgeFactor)}.",
                    "Eco-impact value: ${formatScore(result.ecoImpactValue)}.",
                    "Harm risk: ${formatScore(result.harmRisk)}.",
                    "Accessibility impact: ${formatScore(result.accessibilityImpact)}.",
                    "Rights alignment: ${formatScore(result.rightsAlignment)}.",
                    "Uncertainty score: ${formatScore(result.uncertaintyScore)}."
                )
            )

            ExplanationAudience.POLICY_REVIEWER -> universal.copy(
                audience = ExplanationAudience.POLICY_REVIEWER,
                technicalDetails = listOf(
                    "Verify advisory-only operation, human review, accessible notice, accessible explanation, appeal availability, data minimization, purpose limitation, retention, and deletion controls.",
                    "Verify that no prohibited status is used as a penalty feature and that no automatic service denial or physical actuation is authorized."
                )
            )
        }
    }

    private fun universalExplanation(
        result: CanonicalAdvisoryResult
    ): AccessibleExplanation {
        return AccessibleExplanation(
            audience = ExplanationAudience.UNIVERSAL,
            whatHappened = result.whatHappened,
            why = result.mainReasons.joinToString(separator = " "),
            certainty = buildCertaintyText(result),
            doesNotMean = doesNotMeanText(result.decisionState),
            nextStep = result.nextStep,
            personOptions = buildPersonOptions(result),
            technicalDetails = emptyList()
        )
    }

    private fun buildCertaintyText(
        result: CanonicalAdvisoryResult
    ): String {
        val uncertaintyPercent = (result.uncertaintyScore * 100.0).toInt()
        val limitationText = result.limitations.joinToString(separator = " ")

        return "This result has an uncertainty score of $uncertaintyPercent percent. $limitationText"
    }

    private fun doesNotMeanText(
        state: AdvisoryDecisionState
    ): String {
        return when (state) {
            AdvisoryDecisionState.APPROVED_FOR_ADVISORY_USE ->
                "This is advisory information. It does not control machinery, deny a service, or replace human judgment."

            AdvisoryDecisionState.NEEDS_REVIEW ->
                "This does not mean the condition is proven unsafe or that anyone loses access to a service. It means more review is needed."

            AdvisoryDecisionState.BLOCKED ->
                "This does not deny a person access to essential information or services. It means the proposed recommendation cannot be used because a required safety, privacy, accessibility, or rights condition was not met."

            AdvisoryDecisionState.INSUFFICIENT_EVIDENCE ->
                "This does not mean there is no issue. It means the available evidence is not sufficient for a responsible advisory conclusion."

            AdvisoryDecisionState.OUT_OF_DOMAIN ->
                "This does not mean the situation is unimportant. It means the available input is outside the approved calculation range."

            AdvisoryDecisionState.RESTRICT_TO_SAFE_OFFLINE_MODE ->
                "This does not remove access to locally available information, correction, or appeal. It means the system cannot verify a current policy bundle while offline."
        }
    }

    private fun buildPersonOptions(
        result: CanonicalAdvisoryResult
    ): String {
        val options = result.nonDigitalOptions.joinToString(separator = "; ")

        return "You may request correction through ${result.correctionPath}. You may appeal through ${result.appealPath}. Non-digital options: $options."
    }

    private fun formatScore(value: Double): String {
        return "%.3f".format(java.util.Locale.ROOT, value)
    }
}
