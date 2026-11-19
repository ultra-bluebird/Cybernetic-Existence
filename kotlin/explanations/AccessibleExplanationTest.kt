package org.augmentedhub.explanations

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AccessibleExplanationTest {
    private fun result(
        state: AdvisoryDecisionState = AdvisoryDecisionState.NEEDS_REVIEW
    ): CanonicalAdvisoryResult {
        return CanonicalAdvisoryResult(
            decisionState = state,
            whatHappened = "The route requires review before it can be recommended.",
            mainReasons = listOf(
                "Shade coverage is incomplete.",
                "Accessibility evidence is older than the configured freshness period."
            ),
            knowledgeFactor = 0.74,
            ecoImpactValue = 0.82,
            harmRisk = 0.18,
            accessibilityImpact = 0.76,
            rightsAlignment = 0.92,
            uncertaintyScore = 0.31,
            limitations = listOf(
                "The temperature estimate uses a surface-temperature proxy.",
                "A current route inspection has not yet been recorded."
            ),
            nextStep = "Request a route inspection and community review.",
            correctionPath = "an accessible phone, mail, or in-person correction request",
            appealPath = "the accessible community appeal workflow",
            nonDigitalOptions = listOf(
                "telephone",
                "relay service",
                "postal mail",
                "accessible in-person support"
            )
        )
    }

    @Test
    fun universalExplanationContainsAllRequiredFields() {
        val explanation = AccessibleExplanationFactory.create(
            result = result(),
            audience = ExplanationAudience.UNIVERSAL
        )

        assertTrue(explanation.whatHappened.isNotBlank())
        assertTrue(explanation.why.isNotBlank())
        assertTrue(explanation.certainty.isNotBlank())
        assertTrue(explanation.doesNotMean.isNotBlank())
        assertTrue(explanation.nextStep.isNotBlank())
        assertTrue(explanation.personOptions.isNotBlank())
    }

    @Test
    fun roleSpecificViewPreservesUniversalFacts() {
        val universal = AccessibleExplanationFactory.create(
            result = result(),
            audience = ExplanationAudience.UNIVERSAL
        )

        val researcher = AccessibleExplanationFactory.create(
            result = result(),
            audience = ExplanationAudience.RESEARCHER
        )

        assertEquals(universal.whatHappened, researcher.whatHappened)
        assertEquals(universal.why, researcher.why)
        assertEquals(universal.certainty, researcher.certainty)
        assertEquals(universal.doesNotMean, researcher.doesNotMean)
        assertEquals(universal.nextStep, researcher.nextStep)
        assertEquals(universal.personOptions, researcher.personOptions)
        assertTrue(researcher.technicalDetails.isNotEmpty())
    }

    @Test
    fun blockedExplanationDoesNotClaimServiceDenial() {
        val explanation = AccessibleExplanationFactory.create(
            result = result(AdvisoryDecisionState.BLOCKED),
            audience = ExplanationAudience.UNIVERSAL
        )

        assertTrue(
            explanation.doesNotMean.contains(
                "does not deny a person access to essential information or services"
            )
        )
    }
}
