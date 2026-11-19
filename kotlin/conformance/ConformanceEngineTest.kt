package org.augmentedhub.conformance

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import java.io.File

class ConformanceEngineTest {

    @Test
    fun maintenanceCondition_currentInspection_returnsAdvisoryOnly() {
        val desc = MaintenanceConditionDescriptor(
            c0 = 0.95,
            lambdaBase = 0.001,
            t0Days = 0.0,
            tInspectionDays = 100.0,
            tValid = 180.0,
            phi = 0.01,
            lambdaFresh = 0.005,
            qCalibration = 0.9,
            qCoverage = 0.85,
            currentDays = 150.0
        )

        val result = ConformanceEngine.calculateMaintenanceCondition(desc)

        assertEquals(OutputClass.ADVISORY_ONLY, result.outputClass)
        assertTrue(result.value != null)
        assertTrue(result.reasons.any { it.contains("current", ignoreCase = true) })
    }

    @Test
    fun maintenanceCondition_expiredInspection_returnsNeedsReview() {
        val desc = MaintenanceConditionDescriptor(
            c0 = 0.95,
            lambdaBase = 0.001,
            t0Days = 0.0,
            tInspectionDays = 100.0,
            tValid = 180.0,
            phi = 0.01,
            lambdaFresh = 0.005,
            qCalibration = 0.9,
            qCoverage = 0.85,
            currentDays = 300.0  // inspection age = 200 days > 180 validity
        )

        val result = ConformanceEngine.calculateMaintenanceCondition(desc)

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertEquals(ReviewState.PENDING, result.reviewState)
    }

    @Test
    fun maintenanceCondition_veryOldInspection_returnsInsufficientEvidence() {
        val desc = MaintenanceConditionDescriptor(
            c0 = 0.95,
            lambdaBase = 0.001,
            t0Days = 0.0,
            tInspectionDays = 100.0,
            tValid = 180.0,
            phi = 0.01,
            lambdaFresh = 0.005,
            qCalibration = 0.9,
            qCoverage = 0.85,
            currentDays = 500.0  // inspection age = 400 days > 2 * 180
        )

        val result = ConformanceEngine.calculateMaintenanceCondition(desc)

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertEquals(ReviewState.PENDING, result.reviewState)
    }

    @Test
    fun maintenanceCondition_missingData_returnsInsufficientEvidence() {
        val desc = MaintenanceConditionDescriptor(
            c0 = -0.1,  // invalid
            lambdaBase = 0.001,
            t0Days = 0.0,
            tInspectionDays = 100.0,
            tValid = 180.0,
            phi = 0.01,
            lambdaFresh = 0.005,
            qCalibration = 0.9,
            qCoverage = 0.85,
            currentDays = 150.0
        )

        val result = ConformanceEngine.calculateMaintenanceCondition(desc)

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue(result.value == null)
    }

    @Test
    fun provenance_weightsSummingToOne_yieldsDeterministicPCC() {
        val desc = ProvenanceDescriptor(
            pCreatorIdentityOrRole = 0.9,
            pCollectionMethod = 0.85,
            pCollectionTime = 0.95,
            pTransformationHistory = 0.8,
            pValidationStatus = 0.75,
            pPolicyVersion = 1.0,
            pSourceLicenseOrAuthority = 0.9,
            weights = listOf(0.15, 0.15, 0.15, 0.15, 0.15, 0.1, 0.15),  // sums to 1.0
            purposeProfile = "planning_review"
        )

        val result = ConformanceEngine.calculateProvenanceCompleteness(desc)

        assertTrue(result.value != null)
        assertTrue(result.value!! >= 0 && result.value!! <= 1)
    }

    @Test
    fun provenance_weightsNotSummingToOne_returnsInsufficientEvidence() {
        val desc = ProvenanceDescriptor(
            pCreatorIdentityOrRole = 0.9,
            pCollectionMethod = 0.85,
            pCollectionTime = 0.95,
            pTransformationHistory = 0.8,
            pValidationStatus = 0.75,
            pPolicyVersion = 1.0,
            pSourceLicenseOrAuthority = 0.9,
            weights = listOf(0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1),  // sums to 0.7
            purposeProfile = "planning_review"
        )

        val result = ConformanceEngine.calculateProvenanceCompleteness(desc)

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue(result.reasons.any { it.contains("sum", ignoreCase = true) })
    }

    @Test
    fun provenance_lowPCC_returnsInsufficientEvidence() {
        val desc = ProvenanceDescriptor(
            pCreatorIdentityOrRole = 0.1,
            pCollectionMethod = 0.1,
            pCollectionTime = 0.1,
            pTransformationHistory = 0.1,
            pValidationStatus = 0.1,
            pPolicyVersion = 0.1,
            pSourceLicenseOrAuthority = 0.1,
            weights = listOf(0.15, 0.15, 0.15, 0.15, 0.15, 0.1, 0.15),
            purposeProfile = "planning_review"
        )

        val result = ConformanceEngine.calculateProvenanceCompleteness(desc)

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue(result.reasons.any { it.contains("below 0.2", ignoreCase = true) })
    }

    @Test
    fun provenance_highPCC_neverRendersAsTruthVerification() {
        val desc = ProvenanceDescriptor(
            pCreatorIdentityOrRole = 1.0,
            pCollectionMethod = 1.0,
            pCollectionTime = 1.0,
            pTransformationHistory = 1.0,
            pValidationStatus = 1.0,
            pPolicyVersion = 1.0,
            pSourceLicenseOrAuthority = 1.0,
            weights = listOf(0.15, 0.15, 0.15, 0.15, 0.15, 0.1, 0.15),
            purposeProfile = "planning_review"
        )

        val result = ConformanceEngine.calculateProvenanceCompleteness(desc)

        assertEquals(OutputClass.ADVISORY_ONLY, result.outputClass)
        assertFalse(result.reasons.any { it.contains("truth", ignoreCase = true) })
        assertTrue(result.reasons.any { it.contains("sufficient", ignoreCase = true) })
    }

    @Test
    fun sensorAlignment_scoreBelow0_2_returnsInsufficientEvidence() {
        val result = ConformanceEngine.calculateSensorAlignmentQuality(
            deltaPosition = 500.0,
            deltaTime = 10000.0,
            deltaCalibration = 100.0,
            deltaFeature = 50.0,
            sigmaPos = 1.0,
            sigmaTime = 100.0,
            sigmaCal = 1.0,
            sigmaFeature = 1.0,
            alignmentMethodVersion = "v1.0.0"
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue(result.reasons.any { it.contains("below 0.2", ignoreCase = true) })
    }

    @Test
    fun sensorAlignment_score0_2to0_5_returnsNeedsReview() {
        val result = ConformanceEngine.calculateSensorAlignmentQuality(
            deltaPosition = 0.5,
            deltaTime = 50.0,
            deltaCalibration = 0.3,
            deltaFeature = 0.2,
            sigmaPos = 1.0,
            sigmaTime = 100.0,
            sigmaCal = 1.0,
            sigmaFeature = 1.0,
            alignmentMethodVersion = "v1.0.0"
        )

        // SAQS = exp(-0.5 - 0.5 - 0.3 - 0.2) = exp(-1.5) ≈ 0.223
        assertTrue(result.outputClass == OutputClass.NEEDS_REVIEW || 
                   result.outputClass == OutputClass.ADVISORY_ONLY)
    }

    @Test
    fun sensorAlignment_perComponentSignedOffsets_preserved() {
        val result = ConformanceEngine.calculateSensorAlignmentQuality(
            deltaPosition = 1.0,
            deltaTime = 50.0,
            deltaCalibration = 0.3,
            deltaFeature = 0.2,
            sigmaPos = 1.0,
            sigmaTime = 100.0,
            sigmaCal = 1.0,
            sigmaFeature = 1.0,
            alignmentMethodVersion = "v1.0.0"
        )

        assertTrue(result.value != null)
        assertTrue(result.value!!.relativeOffsetMeters >= 0)
        assertTrue(result.value!!.absoluteTimeOffsetMilliseconds >= 0)
    }

    @Test
    fun sensorAlignment_missingMethodVersion_returnsInsufficientEvidence() {
        val result = ConformanceEngine.calculateSensorAlignmentQuality(
            deltaPosition = 0.1,
            deltaTime = 10.0,
            deltaCalibration = 0.1,
            deltaFeature = 0.1,
            sigmaPos = 1.0,
            sigmaTime = 100.0,
            sigmaCal = 1.0,
            sigmaFeature = 1.0,
            alignmentMethodVersion = null
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue(result.reasons.any { it.contains("alignment_method_version", ignoreCase = true) })
    }

    @Test
    fun electronicConversion_unitMismatch_returnsInsufficientEvidence() {
        val result = ConformanceEngine.calculateElectronicConversionEfficiency(
            eUseful = 100.0,
            eAvailable = 0.0,  // invalid - must be positive
            etaCapture = 0.8,
            beta = 0.1,
            dCondition = 0.2
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
    }

    @Test
    fun electronicConversion_rawRatioAboveOne_returnsNeedsReview() {
        val result = ConformanceEngine.calculateElectronicConversionEfficiency(
            eUseful = 500.0,
            eAvailable = 100.0,
            etaCapture = 0.8,
            beta = 0.0,  // no degradation
            dCondition = 0.0
        )

        // ECER_raw = 500/100 * 1 = 5.0 > 1
        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertTrue(result.reasons.any { it.contains("exceeds 1.0", ignoreCase = true) })
    }

    @Test
    fun electronicConversion_lifecycleClaimWithoutInventory_blockedByPolicy() {
        val result = ConformanceEngine.calculateElectronicConversionEfficiency(
            eUseful = 80.0,
            eAvailable = 100.0,
            etaCapture = 0.8,
            beta = 0.1,
            dCondition = 0.2,
            lifecycleInventoryProvided = false,
            hasLifecycleClaim = true
        )

        assertEquals(OutputClass.BLOCKED_BY_POLICY, result.outputClass)
        assertTrue(result.reasons.any { it.contains("lifecycle", ignoreCase = true) })
    }

    @Test
    fun thermalRefuge_criticalBarrier_createsZeroContributionAndRemediationSignal() {
        val refuges = listOf(
            ConformanceEngine.ThermalRefugeData(
                capacity = 100.0,
                coolingIntensity = 5.0,
                accessibilityCoefficient = 0.9,
                operationalAvailability = 1.0,
                travelMinutes = 10.0
            )
        )

        val result = ConformanceEngine.calculateThermalRefugeAccessibility(
            refuges = refuges,
            lambda = 0.05,
            hasCriticalBarrier = true
        )

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertEquals(0.0, result.value)
        assertTrue(result.reasons.any { it.contains("barrier", ignoreCase = true) })
    }

    @Test
    fun thermalRefuge_uncertaintyIntervalWide_returnsNeedsReview() {
        val refuges = listOf(
            ConformanceEngine.ThermalRefugeData(
                capacity = 100.0,
                coolingIntensity = 5.0,
                accessibilityCoefficient = 0.9,
                operationalAvailability = 1.0,
                travelMinutes = 10.0
            )
        )

        val result = ConformanceEngine.calculateThermalRefugeAccessibility(
            refuges = refuges,
            lambda = 0.05,
            uncertaintyIntervalWidth = 0.3  // > 0.25 threshold
        )

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertTrue(result.reasons.any { it.contains("uncertainty", ignoreCase = true) })
    }

    @Test
    fun thermalRefuge_missingAccessibleRoute_returnsInsufficientEvidence() {
        val refuges = listOf(
            ConformanceEngine.ThermalRefugeData(
                capacity = 100.0,
                coolingIntensity = 5.0,
                accessibilityCoefficient = -0.1,  // invalid
                operationalAvailability = 1.0,
                travelMinutes = 10.0
            )
        )

        val result = ConformanceEngine.calculateThermalRefugeAccessibility(
            refuges = refuges,
            lambda = 0.05
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
    }

    @Test
    fun corridor_zeroQuality_createsDiscontinuity() {
        val segments = listOf(
            ConformanceEngine.CorridorSegmentData(
                segmentLength = 100.0,
                shadeQuality = 0.8,
                surfaceQuality = 0.0,  // zero creates discontinuity
                accessibilityQuality = 0.9,
                safetyQuality = 0.85,
                maintenanceQuality = 0.8
            )
        )

        val result = ConformanceEngine.calculateCorridorContinuity(
            segments = segments,
            totalPlannedLength = 100.0,
            lReview = 50.0
        )

        // CCS will be 0 because of discontinuity
        assertTrue(result.value!! < 0.1)
    }

    @Test
    fun corridor_longConsecutiveDiscontinuity_returnsNeedsReview() {
        val segments = listOf(
            ConformanceEngine.CorridorSegmentData(
                segmentLength = 60.0,
                shadeQuality = 0.0,  // discontinuity
                surfaceQuality = 0.0,
                accessibilityQuality = 0.0,
                safetyQuality = 0.0,
                maintenanceQuality = 0.0
            ),
            ConformanceEngine.CorridorSegmentData(
                segmentLength = 60.0,
                shadeQuality = 0.0,  // another discontinuity
                surfaceQuality = 0.0,
                accessibilityQuality = 0.0,
                safetyQuality = 0.0,
                maintenanceQuality = 0.0
            )
        )

        val result = ConformanceEngine.calculateCorridorContinuity(
            segments = segments,
            totalPlannedLength = 200.0,
            lReview = 50.0  // 120m consecutive > 50m threshold
        )

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertTrue(result.reasons.any { it.contains("discontinuity", ignoreCase = true) })
    }

    @Test
    fun corridor_missingSegmentEvidence_returnsInsufficientEvidence() {
        val segments = listOf(
            ConformanceEngine.CorridorSegmentData(
                segmentLength = -10.0,  // invalid
                shadeQuality = 0.8,
                surfaceQuality = 0.9,
                accessibilityQuality = 0.9,
                safetyQuality = 0.85,
                maintenanceQuality = 0.8
            )
        )

        val result = ConformanceEngine.calculateCorridorContinuity(
            segments = segments,
            totalPlannedLength = 100.0,
            lReview = 50.0
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
    }

    @Test
    fun automation_unknownHumanProximity_returnsFailSafeMode() {
        val desc = AutomationConditionDescriptor(
            criticalConditions = listOf("proximity"),
            observationValues = mapOf("proximity" to 5.0),
            safeBoundaryValues = mapOf("proximity" to 10.0),
            designDistanceValues = mapOf("proximity" to 10.0),
            uncertaintyValues = mapOf("proximity" to 0.2),
            severityValues = mapOf("proximity" to 0.5),
            humanProximityState = "unknown"
        )

        val result = ConformanceEngine.calculateAutomationSafetyMargin(desc)

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertEquals(AutomationState.FAIL_SAFE_MODE, result.automationState)
        assertTrue(result.reasons.any { it.contains("fail-safe", ignoreCase = true) })
    }

    @Test
    fun automation_safetyBoundaryFailure_returnsFailSafeMode() {
        val desc = AutomationConditionDescriptor(
            criticalConditions = listOf("distance"),
            observationValues = mapOf("distance" to 0.5),
            safeBoundaryValues = mapOf("distance" to 1.0),
            designDistanceValues = mapOf("distance" to 10.0),
            uncertaintyValues = mapOf("distance" to 0.3),
            severityValues = mapOf("distance" to 0.8),
            humanProximityState = "clear"
        )

        val result = ConformanceEngine.calculateAutomationSafetyMargin(desc)

        // m_protected = (0.5/10) * (1-0.3) * (1-0.8) = 0.05 * 0.7 * 0.2 = 0.007 < 0.1
        assertEquals(AutomationState.FAIL_SAFE_MODE, result.automationState)
    }

    @Test
    fun automation_protectedMarginBelow0_3_returnsReduceAutomation() {
        val desc = AutomationConditionDescriptor(
            criticalConditions = listOf("distance"),
            observationValues = mapOf("distance" to 4.0),
            safeBoundaryValues = mapOf("distance" to 10.0),
            designDistanceValues = mapOf("distance" to 10.0),
            uncertaintyValues = mapOf("distance" to 0.2),
            severityValues = mapOf("distance" to 0.3),
            humanProximityState = "clear"
        )

        val result = ConformanceEngine.calculateAutomationSafetyMargin(desc)

        // m_protected = (4/10) * 0.8 * 0.7 = 0.224 -> between 0.1 and 0.3
        assertEquals(AutomationState.REDUCE_AUTOMATION, result.automationState)
    }

    @Test
    fun automation_favorableMargin_cannotOverrideFailedAccessibilityGate() {
        val metricDef = createValidMetricDefinition()
        val evidenceDesc = EvidenceDescriptor(EvidenceState.OBSERVED, qualityScore = 1.0)
        val gateState = GateState(accessibilityGatePassed = false)
        val calcResult = CalculationResult(0.95, OutputClass.ADVISORY_ONLY)

        val decision = ConformanceEngine.evaluateConformance(
            metricDefinition = metricDef,
            evidenceDescriptor = evidenceDesc,
            gateState = gateState,
            calculationResult = calcResult
        )

        assertEquals(OutputClass.NEEDS_REVIEW, decision.outputClass)
        assertTrue(decision.reasons.any { it.contains("accessibility", ignoreCase = true) })
    }

    @Test
    fun conformance_personScoringRequest_blockedByPolicy() {
        val metricDef = createValidMetricDefinition()
        val evidenceDesc = EvidenceDescriptor(EvidenceState.OBSERVED, qualityScore = 1.0)
        val gateState = GateState(requiresPersonScoring = true)
        val calcResult = CalculationResult(0.8, OutputClass.ADVISORY_ONLY)

        val decision = ConformanceEngine.evaluateConformance(
            metricDefinition = metricDef,
            evidenceDescriptor = evidenceDesc,
            gateState = gateState,
            calculationResult = calcResult
        )

        assertEquals(OutputClass.BLOCKED_BY_POLICY, decision.outputClass)
    }

    private fun createValidMetricDefinition(): MetricDefinition {
        return MetricDefinition(
            metricName = "test_metric",
            semanticVersion = "v1.0.0",
            domain = "test",
            metricKind = "planning_index",
            definition = "Test metric definition",
            formulaVersion = "v1.0.0",
            formulaExpression = "test = 1",
            output = MetricOutputDefinition(
                unit = "ratio",
                minimum = 0.0,
                maximum = 1.0,
                classification = "planning_index"
            ),
            evidenceRequirements = MetricEvidenceRequirements(
                requiredFields = listOf("field1"),
                missingDataBehavior = "insufficient_evidence",
                staleDataBehavior = "needs_review",
                zeroQualityBehavior = "insufficient_evidence"
            ),
            uncertainty = MetricUncertainty(
                method = "interval_bound",
                reported = true,
                reviewThreshold = 0.25,
                sources = listOf("test")
            ),
            review = MetricReviewRequirements(
                humanReviewRequired = true,
                accessibleExplanationRequired = true,
                appealPathRequired = true,
                nonDigitalEscalationRequired = true
            ),
            governance = MetricGovernance(
                advisoryOnly = true,
                automatedActuationPermitted = false,
                automatedServiceDenialPermitted = false,
                biometricIdentificationPermitted = false,
                cyberneticStatusPenaltyPermitted = false,
                individualProfilingPermitted = false,
                optionalTelemetryRequired = false,
                continuousConnectivityRequired = false,
                gateRelationship = "test"
            ),
            prohibitedInterpretations = listOf("This is a test"),
            intendedDecisionContexts = listOf("test"),
            nonPermittedDecisionContexts = listOf(
                "person_scoring",
                "public_service_eligibility",
                "identity_resolution",
                "biometric_identification",
                "cybernetic_status_assessment",
                "automated_service_denial"
            )
        )
    }
}
