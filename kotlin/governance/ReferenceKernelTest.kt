package org.augmentedhub.governance

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ReferenceKernelTest {
    private fun validEvidenceQuality(): EvidenceQuality {
        return EvidenceQuality(
            measurement = 0.90,
            calibration = 0.90,
            provenance = 0.90,
            freshness = 0.90,
            coverage = 0.90,
            review = 0.90,
            weights = listOf(
                0.20,
                0.20,
                0.15,
                0.15,
                0.15,
                0.15
            )
        )
    }

    private fun validKerInput(): KerInput {
        return KerInput(
            ecoImpactValue = 0.80,
            harmRisk = 0.20,
            accessibilityImpact = 0.90,
            rightsAlignment = 0.90
        )
    }

    private fun validGovernanceInput(): GovernanceInput {
        return GovernanceInput(
            advisoryOnly = true,
            humanReviewAvailable = true,
            accessibleNoticeAvailable = true,
            accessibleExplanationAvailable = true,
            appealPathAvailable = true,
            dataMinimizationConfirmed = true,
            purposeLimitationConfirmed = true,
            retentionAndDeletionPathAvailable = true,
            requiresContinuousConnectivity = false,
            requiresOptionalTelemetry = false,
            usesBiometricIdentification = false,
            usesCyberneticStatusAsPenalty = false,
            authorizesPhysicalActuation = false,
            authorizesServiceDenial = false
        )
    }

    @Test
    fun approvesACompliantAdvisoryResult() {
        val result = ReferenceKernel.evaluate(
            quality = validEvidenceQuality(),
            ker = validKerInput(),
            governance = validGovernanceInput()
        )

        assertEquals(
            AdvisoryState.APPROVED_FOR_ADVISORY_USE,
            result.state
        )
        assertTrue(result.knowledgeFactor >= 0.60)
        assertTrue(result.reasons.isEmpty())
    }

    @Test
    fun zeroEvidenceQualityReturnsInsufficientEvidence() {
        val result = ReferenceKernel.evaluate(
            quality = EvidenceQuality(
                measurement = 0.90,
                calibration = 0.0,
                provenance = 0.90,
                freshness = 0.90,
                coverage = 0.90,
                review = 0.90,
                weights = listOf(
                    0.20,
                    0.20,
                    0.15,
                    0.15,
                    0.15,
                    0.15
                )
            ),
            ker = validKerInput(),
            governance = validGovernanceInput()
        )

        assertEquals(AdvisoryState.INSUFFICIENT_EVIDENCE, result.state)
        assertEquals(0.0, result.knowledgeFactor)
    }

    @Test
    fun highHarmRiskBlocksRegardlessOfEcoImpact() {
        val result = ReferenceKernel.evaluate(
            quality = validEvidenceQuality(),
            ker = KerInput(
                ecoImpactValue = 1.0,
                harmRisk = 0.46,
                accessibilityImpact = 1.0,
                rightsAlignment = 1.0
            ),
            governance = validGovernanceInput()
        )

        assertEquals(AdvisoryState.BLOCKED, result.state)
        assertTrue(
            result.reasons.contains(
                "Harm risk exceeds the non-compensatory threshold."
            )
        )
    }

    @Test
    fun cyberneticStatusPenaltyBlocksResult() {
        val governance = validGovernanceInput().copy(
            usesCyberneticStatusAsPenalty = true
        )

        val result = ReferenceKernel.evaluate(
            quality = validEvidenceQuality(),
            ker = validKerInput(),
            governance = governance
        )

        assertEquals(AdvisoryState.BLOCKED, result.state)
        assertTrue(
            result.reasons.contains(
                "Cybernetic or assistive status is used as a penalty."
            )
        )
    }

    @Test
    fun continuousConnectivityRequirementBlocksEssentialAdvisoryPath() {
        val governance = validGovernanceInput().copy(
            requiresContinuousConnectivity = true
        )

        val result = ReferenceKernel.evaluate(
            quality = validEvidenceQuality(),
            ker = validKerInput(),
            governance = governance
        )

        assertEquals(AdvisoryState.BLOCKED, result.state)
    }

    @Test
    fun missingHumanReviewRequiresReview() {
        val governance = validGovernanceInput().copy(
            humanReviewAvailable = false
        )

        val result = ReferenceKernel.evaluate(
            quality = validEvidenceQuality(),
            ker = validKerInput(),
            governance = governance
        )

        assertEquals(AdvisoryState.NEEDS_REVIEW, result.state)
        assertTrue(
            result.reasons.contains(
                "A human review path is not available."
            )
        )
    }

    @Test
    fun conservativeResidualRequiresReviewWhenToleranceIsExceeded() {
        val requiresReview = ReferenceKernel.interventionRequiresReview(
            currentResidual = 0.30,
            predictedResidual = 0.31,
            residualUncertainty = 0.02,
            conservatismMultiplier = 1.0,
            epsilon = 0.02
        )

        assertTrue(requiresReview)
    }

    @Test
    fun conservativeResidualDoesNotRequireReviewInsideTolerance() {
        val requiresReview = ReferenceKernel.interventionRequiresReview(
            currentResidual = 0.30,
            predictedResidual = 0.29,
            residualUncertainty = 0.01,
            conservatismMultiplier = 1.0,
            epsilon = 0.02
        )

        assertFalse(requiresReview)
    }
}
