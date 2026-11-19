package org.augmentedhub.governance

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CharterPolicyInputTest {

    @Test
    fun `valid complete input is accepted`() {
        val ker = validKerInput()
        val evidence = validEvidenceInput()
        val uncertainty = validUncertaintyInput()
        val governance = validGovernanceInput()
        val runtime = validRuntimeInput()
        val policyBundle = validPolicyBundleInput()
        val sync = validSyncInput()

        val input = CharterPolicyInput(
            ker = ker,
            evidence = evidence,
            uncertainty = uncertainty,
            governance = governance,
            runtime = runtime,
            policyBundle = policyBundle,
            sync = sync
        )

        assertEquals(false, input.hasInsufficientEvidence())
    }

    @Test
    fun `NaN is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterKerInput(
                knowledgeFactor = Double.NaN,
                ecoImpactValue = 0.8,
                harmRisk = 0.2,
                accessibilityImpact = 0.9,
                rightsAlignment = 0.95
            )
        }
    }

    @Test
    fun `infinite score is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterKerInput(
                knowledgeFactor = Double.POSITIVE_INFINITY,
                ecoImpactValue = 0.8,
                harmRisk = 0.2,
                accessibilityImpact = 0.9,
                rightsAlignment = 0.95
            )
        }
    }

    @Test
    fun `weights that do not sum to one are rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterEvidenceInput(
                qualityScores = listOf(0.8, 0.9, 0.7, 0.6, 0.8, 0.9),
                weights = listOf(0.1, 0.1, 0.1, 0.1, 0.1, 0.1)
            )
        }
    }

    @Test
    fun `negative score is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterKerInput(
                knowledgeFactor = -0.1,
                ecoImpactValue = 0.8,
                harmRisk = 0.2,
                accessibilityImpact = 0.9,
                rightsAlignment = 0.95
            )
        }
    }

    @Test
    fun `continuous-connectivity requirement is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterGovernanceInput(
                advisoryOnly = true,
                automatedActuation = false,
                automatedServiceDenial = false,
                requiresContinuousConnectivity = true,
                requiresOptionalTelemetry = false,
                usesBiometricIdentification = false,
                usesCyberneticStatusAsPenalty = false,
                usesAssistiveTechnologyAsPenalty = false,
                humanReviewAvailable = true,
                accessibleNoticeAvailable = true,
                accessibleExplanationAvailable = true,
                appealPathAvailable = true,
                nonDigitalEscalationAvailable = true,
                dataMinimizationConfirmed = true,
                purposeLimitationConfirmed = true,
                retentionAndDeletionPathAvailable = true
            )
        }
    }

    @Test
    fun `optional-telemetry requirement is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterGovernanceInput(
                advisoryOnly = true,
                automatedActuation = false,
                automatedServiceDenial = false,
                requiresContinuousConnectivity = false,
                requiresOptionalTelemetry = true,
                usesBiometricIdentification = false,
                usesCyberneticStatusAsPenalty = false,
                usesAssistiveTechnologyAsPenalty = false,
                humanReviewAvailable = true,
                accessibleNoticeAvailable = true,
                accessibleExplanationAvailable = true,
                appealPathAvailable = true,
                nonDigitalEscalationAvailable = true,
                dataMinimizationConfirmed = true,
                purposeLimitationConfirmed = true,
                retentionAndDeletionPathAvailable = true
            )
        }
    }

    @Test
    fun `cybernetic-status penalty is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterGovernanceInput(
                advisoryOnly = true,
                automatedActuation = false,
                automatedServiceDenial = false,
                requiresContinuousConnectivity = false,
                requiresOptionalTelemetry = false,
                usesBiometricIdentification = false,
                usesCyberneticStatusAsPenalty = true,
                usesAssistiveTechnologyAsPenalty = false,
                humanReviewAvailable = true,
                accessibleNoticeAvailable = true,
                accessibleExplanationAvailable = true,
                appealPathAvailable = true,
                nonDigitalEscalationAvailable = true,
                dataMinimizationConfirmed = true,
                purposeLimitationConfirmed = true,
                retentionAndDeletionPathAvailable = true
            )
        }
    }

    @Test
    fun `missing human review is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterGovernanceInput(
                advisoryOnly = true,
                automatedActuation = false,
                automatedServiceDenial = false,
                requiresContinuousConnectivity = false,
                requiresOptionalTelemetry = false,
                usesBiometricIdentification = false,
                usesCyberneticStatusAsPenalty = false,
                usesAssistiveTechnologyAsPenalty = false,
                humanReviewAvailable = false,
                accessibleNoticeAvailable = true,
                accessibleExplanationAvailable = true,
                appealPathAvailable = true,
                nonDigitalEscalationAvailable = true,
                dataMinimizationConfirmed = true,
                purposeLimitationConfirmed = true,
                retentionAndDeletionPathAvailable = true
            )
        }
    }

    @Test
    fun `missing accessible explanation is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            CharterGovernanceInput(
                advisoryOnly = true,
                automatedActuation = false,
                automatedServiceDenial = false,
                requiresContinuousConnectivity = false,
                requiresOptionalTelemetry = false,
                usesBiometricIdentification = false,
                usesCyberneticStatusAsPenalty = false,
                usesAssistiveTechnologyAsPenalty = false,
                humanReviewAvailable = true,
                accessibleNoticeAvailable = true,
                accessibleExplanationAvailable = false,
                appealPathAvailable = true,
                nonDigitalEscalationAvailable = true,
                dataMinimizationConfirmed = true,
                purposeLimitationConfirmed = true,
                retentionAndDeletionPathAvailable = true
            )
        }
    }

    @Test
    fun `zero quality score remains constructible for later insufficient-evidence handling`() {
        val evidence = CharterEvidenceInput(
            qualityScores = listOf(0.0, 0.9, 0.7, 0.6, 0.8, 0.9),
            weights = listOf(0.166667, 0.166667, 0.166667, 0.166667, 0.166666, 0.166666)
        )

        val input = CharterPolicyInput(
            ker = validKerInput(),
            evidence = evidence,
            uncertainty = validUncertaintyInput(),
            governance = validGovernanceInput(),
            runtime = validRuntimeInput(),
            policyBundle = validPolicyBundleInput(),
            sync = validSyncInput()
        )

        assertEquals(true, input.hasInsufficientEvidence())
    }
}

private fun validKerInput(): CharterKerInput {
    return CharterKerInput(
        knowledgeFactor = 0.78,
        ecoImpactValue = 0.82,
        harmRisk = 0.18,
        accessibilityImpact = 0.86,
        rightsAlignment = 0.92
    )
}

private fun validEvidenceInput(): CharterEvidenceInput {
    return CharterEvidenceInput(
        qualityScores = listOf(0.8, 0.9, 0.7, 0.6, 0.8, 0.9),
        weights = listOf(0.166667, 0.166667, 0.166667, 0.166667, 0.166666, 0.166666)
    )
}

private fun validUncertaintyInput(): CharterUncertaintyInput {
    return CharterUncertaintyInput(
        uncertaintyScore = 0.24,
        method = "synthetic-first-order-propagation",
        basis = "Synthetic uncertainty basis for test execution only."
    )
}

private fun validGovernanceInput(): CharterGovernanceInput {
    return CharterGovernanceInput(
        advisoryOnly = true,
        automatedActuation = false,
        automatedServiceDenial = false,
        requiresContinuousConnectivity = false,
        requiresOptionalTelemetry = false,
        usesBiometricIdentification = false,
        usesCyberneticStatusAsPenalty = false,
        usesAssistiveTechnologyAsPenalty = false,
        humanReviewAvailable = true,
        accessibleNoticeAvailable = true,
        accessibleExplanationAvailable = true,
        appealPathAvailable = true,
        nonDigitalEscalationAvailable = true,
        dataMinimizationConfirmed = true,
        purposeLimitationConfirmed = true,
        retentionAndDeletionPathAvailable = true
    )
}

private fun validRuntimeInput(): CharterRuntimeInput {
    return CharterRuntimeInput(
        networkAvailable = true,
        localPolicyEvaluationAvailable = true,
        hasValidLocalPolicy = true
    )
}

private fun validPolicyBundleInput(): CharterPolicyBundleInput {
    return CharterPolicyBundleInput(
        policyId = "augmented-hub-comprehensive-policy",
        policyVersion = "2026.08.28",
        signatureValid = true,
        versionKnown = true,
        notExpired = true
    )
}

private fun validSyncInput(): CharterSyncInput {
    return CharterSyncInput(
        recordIsProtected = false,
        concurrentUpdateDetected = false,
        lastWriterWinsRequested = false,
        preserveAllVersions = false,
        humanReviewRequired = false
    )
}
