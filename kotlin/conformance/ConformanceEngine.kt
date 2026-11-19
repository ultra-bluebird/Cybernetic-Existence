package org.augmentedhub.conformance

import kotlin.math.exp
import kotlin.math.clamp
import kotlin.math.abs

/**
 * Evidence descriptor for passing evidence state to calculations.
 */
data class EvidenceDescriptor(
    val evidenceState: EvidenceState,
    val qualityScore: Double = 1.0,
    val ageDays: Double = 0.0,
    val validityDays: Double = 365.0,
    val isCompatible: EvidenceCompatibility = EvidenceCompatibility.COMPATIBLE,
    val hasConflict: Boolean = false
)

/**
 * Community observation descriptor.
 */
data class CommunityObservationDescriptor(
    val observationCount: Int,
    val consensusLevel: Double,
    val accessibilityRubricVersion: String? = null
)

/**
 * Sensor alignment descriptor with per-component offsets.
 */
data class SensorAlignmentDescriptor(
    val relativeOffsetXMeters: Double,
    val relativeOffsetYMeters: Double,
    val relativeOffsetZMeters: Double,
    val relativeOffsetMeters: Double,
    val signedTimeOffsetMilliseconds: Double,
    val absoluteTimeOffsetMilliseconds: Double,
    val signedCalibrationResidual: Double,
    val absoluteCalibrationResidual: Double,
    val signedFeatureResidual: Double,
    val absoluteFeatureResidual: Double,
    val alignmentMethodVersion: String?,
    val lastAlignmentCheck: String?,
    val environmentalConditionsDuringCheck: String?
)

/**
 * Maintenance condition descriptor.
 */
data class MaintenanceConditionDescriptor(
    val c0: Double,
    val lambdaBase: Double,
    val t0Days: Double,
    val tInspectionDays: Double,
    val tValid: Double,
    val phi: Double,
    val lambdaFresh: Double,
    val qCalibration: Double,
    val qCoverage: Double,
    val currentDays: Double
)

/**
 * Provenance descriptor with weighted elements.
 */
data class ProvenanceDescriptor(
    val pCreatorIdentityOrRole: Double,
    val pCollectionMethod: Double,
    val pCollectionTime: Double,
    val pTransformationHistory: Double,
    val pValidationStatus: Double,
    val pPolicyVersion: Double,
    val pSourceLicenseOrAuthority: Double,
    val weights: List<Double>,
    val purposeProfile: String
)

/**
 * Automation condition descriptor.
 */
data class AutomationConditionDescriptor(
    val criticalConditions: List<String>,
    val observationValues: Map<String, Double>,
    val safeBoundaryValues: Map<String, Double>,
    val designDistanceValues: Map<String, Double>,
    val uncertaintyValues: Map<String, Double>,
    val severityValues: Map<String, Double>,
    val humanProximityState: String,
    val epsilon: Double = 0.000001
)

/**
 * Calculation result with value and status.
 */
data class CalculationResult<T>(
    val value: T?,
    val outputClass: OutputClass,
    val automationState: AutomationState? = null,
    val reviewState: ReviewState = ReviewState.NOT_REQUIRED,
    val reasons: List<String> = emptyList(),
    val metadata: Map<String, Any> = emptyMap()
)

/**
 * Gate state for conformance evaluation.
 */
data class GateState(
    val requiresPersonScoring: Boolean = false,
    val requiresServiceEligibility: Boolean = false,
    val requiresIdentityResolution: Boolean = false,
    val requiresBiometricIdentification: Boolean = false,
    val requiresCyberneticStatusAssessment: Boolean = false,
    val requiresBehaviorProfiling: Boolean = false,
    val accessibilityGatePassed: Boolean = true,
    val rightsAlignmentGatePassed: Boolean = true,
    val consentGatePassed: Boolean = true,
    val humanReviewGatePassed: Boolean = true,
    val essentialServiceContinuityPreserved: Boolean = true
)

/**
 * Conformance decision result.
 */
data class ConformanceDecision(
    val outputClass: OutputClass,
    val automationState: AutomationState? = null,
    val reviewState: ReviewState = ReviewState.NOT_REQUIRED,
    val releaseClass: ReleaseClass = ReleaseClass.PUBLIC,
    val reasons: List<String> = emptyList(),
    val metricName: String,
    val explanationPayload: ExplanationPayload? = null
)

/**
 * Conformance receipt for audit trail.
 */
data class ConformanceReceipt(
    val decision: ConformanceDecision,
    val timestamp: String,
    val metricVersion: String,
    val evidenceSummary: String,
    val uncertaintyStatement: String,
    val humanReviewRequired: Boolean,
    val nonDigitalEscalationAvailable: Boolean,
    val appealPath: String,
    val correctionPath: String
)

/**
 * Explanation payload for rendering.
 */
data class ExplanationPayload(
    val whatWasEvaluated: String,
    val advisoryNature: String,
    val evidenceStatus: String,
    val uncertaintyMissingOrStale: String?,
    val noPersonAssessment: String,
    val noAutomatedAction: String,
    val humanReviewRequirement: String?,
    val nonDigitalEscalation: String?
)

/**
 * Deterministic calculation functions for conformance metrics.
 * All functions validate bounds and return INSUFFICIENT_EVIDENCE
 * rather than fabricating missing values.
 */
object ConformanceEngine {

    private const val EPSILON = 0.000001

    /**
     * Calculate maintenance condition estimate using decay model.
     * C_estimated(t) = clamp(C_0 * exp(-lambda_base * (t - t_0)) * max(0, 1 - phi * max(0, t - t_inspection - T_valid)), 0, 1)
     */
    @JvmStatic
    fun calculateMaintenanceCondition(desc: MaintenanceConditionDescriptor): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        // Validate required inputs
        if (desc.c0 < 0 || desc.c0 > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("C_0 must be in [0, 1]"))
        }
        if (desc.lambdaBase < 0 || desc.lambdaBase > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("lambda_base must be in [0, 1]"))
        }
        if (desc.phi < 0 || desc.phi > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("phi must be in [0, 1]"))
        }
        if (desc.lambdaFresh < 0 || desc.lambdaFresh > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("lambda_fresh must be in [0, 1]"))
        }
        if (desc.qCalibration < 0 || desc.qCalibration > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("Q_calibration must be in [0, 1]"))
        }
        if (desc.qCoverage < 0 || desc.qCoverage > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("Q_coverage must be in [0, 1]"))
        }
        if (desc.tValid <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("T_valid must be positive"))
        }

        val inspectionAge = desc.currentDays - desc.tInspectionDays
        
        // Status rules based on inspection age
        return when {
            inspectionAge > 2 * desc.tValid -> {
                CalculationResult(
                    null,
                    OutputClass.INSUFFICIENT_EVIDENCE,
                    reviewState = ReviewState.PENDING,
                    reasons = listOf("Inspection age (${inspectionAge.toInt()} days) exceeds twice the validity period (${(2 * desc.tValid).toInt()} days)")
                )
            }
            inspectionAge > desc.tValid -> {
                // Calculate decayed condition but mark as needs review
                val timeSinceT0 = desc.currentDays - desc.t0Days
                val timeSinceInspectionExpired = maxOf(0.0, inspectionAge - desc.tValid)
                
                val baseDecay = exp(-desc.lambdaBase * timeSinceT0)
                val expiryPenalty = maxOf(0.0, 1.0 - desc.phi * timeSinceInspectionExpired)
                val cEstimated = clamp(desc.c0 * baseDecay * expiryPenalty, 0.0, 1.0)
                
                CalculationResult(
                    cEstimated,
                    OutputClass.NEEDS_REVIEW,
                    reviewState = ReviewState.PENDING,
                    reasons = listOf("Inspection age (${inspectionAge.toInt()} days) exceeds validity period (${desc.tValid.toInt()} days)")
                )
            }
            else -> {
                // Inspection is current - advisory only
                val timeSinceT0 = desc.currentDays - desc.t0Days
                val baseDecay = exp(-desc.lambdaBase * timeSinceT0)
                val cEstimated = clamp(desc.c0 * baseDecay, 0.0, 1.0)
                
                CalculationResult(
                    cEstimated,
                    OutputClass.ADVISORY_ONLY,
                    reviewState = ReviewState.NOT_REQUIRED,
                    reasons = listOf("Inspection is current (${inspectionAge.toInt()} days <= ${desc.tValid.toInt()} days validity)")
                )
            }
        }
    }

    /**
     * Calculate inspection freshness separately.
     * F_inspection(t) = 1 when inspection_age <= T_valid, otherwise exp(-lambda_fresh * (inspection_age - T_valid))
     */
    @JvmStatic
    fun calculateInspectionFreshness(inspectionAge: Double, tValid: Double, lambdaFresh: Double): CalculationResult<Double> {
        if (tValid <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("T_valid must be positive"))
        }
        if (lambdaFresh < 0 || lambdaFresh > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("lambda_fresh must be in [0, 1]"))
        }
        if (inspectionAge < 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, reasons = listOf("inspection_age cannot be negative"))
        }

        val freshness = if (inspectionAge <= tValid) {
            1.0
        } else {
            exp(-lambdaFresh * (inspectionAge - tValid))
        }

        return CalculationResult(
            clamp(freshness, 0.0, 1.0),
            OutputClass.ADVISORY_ONLY,
            reasons = listOf("Inspection freshness calculated")
        )
    }

    /**
     * Calculate provenance chain completeness using weighted geometric mean.
     * PCC = product(p_i ^ w_i)
     */
    @JvmStatic
    fun calculateProvenanceCompleteness(desc: ProvenanceDescriptor): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        val pValues = listOf(
            desc.pCreatorIdentityOrRole,
            desc.pCollectionMethod,
            desc.pCollectionTime,
            desc.pTransformationHistory,
            desc.pValidationStatus,
            desc.pPolicyVersion,
            desc.pSourceLicenseOrAuthority
        )

        // Validate all p_i in [0, 1]
        for ((i, p) in pValues.withIndex()) {
            if (p < 0 || p > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE, 
                    reasons = listOf("Provenance element $i must be in [0, 1], got $p"))
            }
        }

        // Validate weights are non-negative
        for ((i, w) in desc.weights.withIndex()) {
            if (w < 0) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Weight $i must be non-negative, got $w"))
            }
        }

        // Validate weights sum to 1 within tolerance
        val weightSum = desc.weights.sum()
        if (abs(weightSum - 1.0) > 0.001) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Weights must sum to 1 within tolerance, got $weightSum"))
        }

        if (pValues.size != desc.weights.size) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Number of p values (${pValues.size}) must match number of weights (${desc.weights.size})"))
        }

        // Calculate weighted geometric mean
        var pcc = 1.0
        for ((p, w) in pValues.zip(desc.weights)) {
            if (p == 0.0) {
                pcc = 0.0
                break
            }
            pcc *= Math.pow(p, w)
        }

        // Status rules
        return when {
            pcc < 0.2 -> CalculationResult(
                pcc,
                OutputClass.INSUFFICIENT_EVIDENCE,
                reviewState = ReviewState.PENDING,
                reasons = listOf("PCC ($pcc) below 0.2 threshold")
            )
            pcc < 0.5 -> CalculationResult(
                pcc,
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("PCC ($pcc) between 0.2 and 0.5")
            )
            else -> CalculationResult(
                pcc,
                OutputClass.ADVISORY_ONLY,
                reviewState = ReviewState.NOT_REQUIRED,
                reasons = listOf("PCC ($pcc) sufficient for declared purpose: ${desc.purposeProfile}")
            )
        }
    }

    /**
     * Calculate sensor alignment quality score.
     * SAQS = exp(-(deltaPosition / sigmaPosition) - (deltaTime / sigmaTime) - (deltaCalibration / sigmaCalibration) - (deltaFeature / sigmaFeature))
     */
    @JvmStatic
    fun calculateSensorAlignmentQuality(
        deltaPosition: Double,
        deltaTime: Double,
        deltaCalibration: Double,
        deltaFeature: Double,
        sigmaPos: Double,
        sigmaTime: Double,
        sigmaCal: Double,
        sigmaFeature: Double,
        alignmentMethodVersion: String?
    ): CalculationResult<SensorAlignmentDescriptor> {
        val reasons = mutableListOf<String>()

        // Validate sigma values are positive
        if (sigmaPos <= EPSILON || sigmaTime <= EPSILON || sigmaCal <= EPSILON || sigmaFeature <= EPSILON) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("All sigma tolerance values must be positive"))
        }

        // Validate deltas are non-negative
        if (deltaPosition < 0 || deltaTime < 0 || deltaCalibration < 0 || deltaFeature < 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("All delta values must be non-negative"))
        }

        // Check alignment method version
        if (alignmentMethodVersion.isNullOrBlank()) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("alignment_method_version is required"))
        }

        // Calculate SAQS
        val exponent = -(deltaPosition / sigmaPos) - (deltaTime / sigmaTime) - 
                       (deltaCalibration / sigmaCal) - (deltaFeature / sigmaFeature)
        val saqs = exp(exponent)

        val descriptor = SensorAlignmentDescriptor(
            relativeOffsetXMeters = deltaPosition / 3.0,
            relativeOffsetYMeters = deltaPosition / 3.0,
            relativeOffsetZMeters = deltaPosition / 3.0,
            relativeOffsetMeters = deltaPosition,
            signedTimeOffsetMilliseconds = deltaTime,
            absoluteTimeOffsetMilliseconds = abs(deltaTime),
            signedCalibrationResidual = deltaCalibration,
            absoluteCalibrationResidual = abs(deltaCalibration),
            signedFeatureResidual = deltaFeature,
            absoluteFeatureResidual = abs(deltaFeature),
            alignmentMethodVersion = alignmentMethodVersion,
            lastAlignmentCheck = null,
            environmentalConditionsDuringCheck = null
        )

        // Status rules
        return when {
            saqs < 0.2 -> CalculationResult(
                descriptor,
                OutputClass.INSUFFICIENT_EVIDENCE,
                reviewState = ReviewState.PENDING,
                reasons = listOf("SAQS ($saqs) below 0.2 - insufficient evidence")
            )
            saqs < 0.5 -> CalculationResult(
                descriptor,
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("SAQS ($saqs) between 0.2 and 0.5 - needs calibration"),
                metadata = mapOf("needs_calibration" to true)
            )
            else -> CalculationResult(
                descriptor,
                OutputClass.ADVISORY_ONLY,
                reviewState = ReviewState.NOT_REQUIRED,
                reasons = listOf("SAQS ($saqs) indicates acceptable alignment quality")
            )
        }
    }

    /**
     * Calculate electronic conversion efficiency ratio.
     * ECER_raw = (E_useful / max(E_available, epsilon)) * (1 / (1 + beta * D_condition))
     * ECER = clamp(ECER_raw, 0, 1)
     */
    @JvmStatic
    fun calculateElectronicConversionEfficiency(
        eUseful: Double,
        eAvailable: Double,
        etaCapture: Double,
        beta: Double,
        dCondition: Double,
        lifecycleInventoryProvided: Boolean = false,
        hasLifecycleClaim: Boolean = false
    ): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        // Validate E_available > 0
        if (eAvailable <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("E_available must be positive"))
        }

        // Validate ranges
        if (eUseful < 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("E_useful must be non-negative"))
        }
        if (etaCapture < 0 || etaCapture > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("eta_capture must be in [0, 1]"))
        }
        if (beta < 0 || beta > 100) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("beta must be in [0, 100]"))
        }
        if (dCondition < 0 || dCondition > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("D_condition must be in [0, 1]"))
        }

        // Check lifecycle claim without inventory
        if (hasLifecycleClaim && !lifecycleInventoryProvided) {
            return CalculationResult(null, OutputClass.BLOCKED_BY_POLICY,
                reasons = listOf("Lifecycle claim requires lifecycle inventory"))
        }

        // Calculate ECER
        val ecerRaw = (eUseful / maxOf(eAvailable, EPSILON)) * (1.0 / (1.0 + beta * dCondition))
        val ecer = clamp(ecerRaw, 0.0, 1.0)

        // Calculate expected output and residual
        val eExpected = etaCapture * eAvailable * (1.0 / (1.0 + beta * dCondition))
        val residual = abs(eUseful - eExpected) / maxOf(eExpected, EPSILON)

        // Status rules
        return when {
            ecerRaw > 1.0 -> CalculationResult(
                ecer,
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("ECER_raw ($ecerRaw) exceeds 1.0 - requires review"),
                metadata = mapOf("ecer_raw" to ecerRaw, "conversion_model_residual" to residual)
            )
            else -> CalculationResult(
                ecer,
                OutputClass.ADVISORY_ONLY,
                reviewState = ReviewState.NOT_REQUIRED,
                reasons = listOf("ECER ($ecer) calculated successfully"),
                metadata = mapOf("ecer_raw" to ecerRaw, "conversion_model_residual" to residual)
            )
        }
    }

    /**
     * Calculate thermal refuge accessibility index.
     * TRAI_j = sum(capacity * coolingIntensity * accessibilityCoefficient * operationalAvailability * exp(-lambda * accessibleTravelMinutes)) / max(sum(capacity * coolingIntensity * accessibilityCoefficient * operationalAvailability), epsilon)
     */
    @JvmStatic
    fun calculateThermalRefugeAccessibility(
        refuges: List<ThermalRefugeData>,
        lambda: Double,
        epsilon: Double = 0.000001,
        hasCriticalBarrier: Boolean = false,
        uncertaintyIntervalWidth: Double = 0.0
    ): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        // Validate inputs
        if (lambda < 0 || lambda > 1) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("lambda must be in [0, 1]"))
        }
        if (epsilon <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("epsilon must be positive"))
        }

        // Validate each refuge
        for ((i, refuge) in refuges.withIndex()) {
            if (refuge.capacity < 0) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Refuge $i capacity must be non-negative"))
            }
            if (refuge.coolingIntensity < 0) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Refuge $i cooling_intensity must be non-negative"))
            }
            if (refuge.accessibilityCoefficient < 0 || refuge.accessibilityCoefficient > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Refuge $i accessibility_coefficient must be in [0, 1]"))
            }
            if (refuge.operationalAvailability < 0 || refuge.operationalAvailability > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Refuge $i operational_availability must be in [0, 1]"))
            }
            if (refuge.travelMinutes < 0) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Refuge $i travel_minutes must be non-negative"))
            }
        }

        // Handle critical barrier - zero positive contribution
        if (hasCriticalBarrier) {
            return CalculationResult(
                0.0,
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Critical access barrier detected - zero positive contribution, remediation required")
            )
        }

        // Calculate numerator and denominator
        var numerator = 0.0
        var denominator = 0.0

        for (refuge in refuges) {
            val weight = refuge.capacity * refuge.coolingIntensity * 
                        refuge.accessibilityCoefficient * refuge.operationalAvailability
            val decayFactor = exp(-lambda * refuge.travelMinutes)
            
            numerator += weight * decayFactor
            denominator += weight
        }

        val trai = numerator / maxOf(denominator, epsilon)

        // Check uncertainty interval width
        if (uncertaintyIntervalWidth > 0.25) {
            return CalculationResult(
                clamp(trai, 0.0, 1.0),
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Uncertainty interval width ($uncertaintyIntervalWidth) exceeds 0.25 threshold")
            )
        }

        return CalculationResult(
            clamp(trai, 0.0, 1.0),
            OutputClass.ADVISORY_ONLY,
            reviewState = ReviewState.NOT_REQUIRED,
            reasons = listOf("TRAI calculated successfully")
        )
    }

    data class ThermalRefugeData(
        val capacity: Double,
        val coolingIntensity: Double,
        val accessibilityCoefficient: Double,
        val operationalAvailability: Double,
        val travelMinutes: Double
    )

    /**
     * Calculate corridor continuity score.
     * segmentContribution = segmentLength * shadeQuality * surfaceQuality * accessibilityQuality * safetyQuality * maintenanceQuality
     * CCS = sum(segmentContribution) / (totalPlannedLength + epsilon)
     */
    @JvmStatic
    fun calculateCorridorContinuity(
        segments: List<CorridorSegmentData>,
        totalPlannedLength: Double,
        lReview: Double,
        epsilon: Double = 0.000001,
        maxMinFairnessMode: Boolean = false
    ): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        // Validate inputs
        if (totalPlannedLength <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("total_planned_length must be positive"))
        }
        if (lReview <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("L_review must be positive"))
        }
        if (epsilon <= 0) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("epsilon must be positive"))
        }

        // Validate segments
        for ((i, seg) in segments.withIndex()) {
            if (seg.segmentLength < 0) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i length must be non-negative"))
            }
            if (seg.shadeQuality < 0 || seg.shadeQuality > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i shade_quality must be in [0, 1]"))
            }
            if (seg.surfaceQuality < 0 || seg.surfaceQuality > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i surface_quality must be in [0, 1]"))
            }
            if (seg.accessibilityQuality < 0 || seg.accessibilityQuality > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i accessibility_quality must be in [0, 1]"))
            }
            if (seg.safetyQuality < 0 || seg.safetyQuality > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i safety_quality must be in [0, 1]"))
            }
            if (seg.maintenanceQuality < 0 || seg.maintenanceQuality > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("Segment $i maintenance_quality must be in [0, 1]"))
            }
        }

        // Calculate segment contributions and track discontinuities
        var sumContributions = 0.0
        var consecutiveDiscontinuityLength = 0.0
        var maxConsecutiveDiscontinuityLength = 0.0

        for (seg in segments) {
            val hasDiscontinuity = seg.shadeQuality == 0.0 || 
                                  seg.surfaceQuality == 0.0 ||
                                  seg.accessibilityQuality == 0.0 ||
                                  seg.safetyQuality == 0.0 ||
                                  seg.maintenanceQuality == 0.0

            if (!hasDiscontinuity) {
                val contribution = seg.segmentLength * seg.shadeQuality * seg.surfaceQuality *
                                  seg.accessibilityQuality * seg.safetyQuality * seg.maintenanceQuality
                sumContributions += contribution
            }

            // Track consecutive discontinuities
            if (hasDiscontinuity) {
                consecutiveDiscontinuityLength += seg.segmentLength
                maxConsecutiveDiscontinuityLength = maxOf(maxConsecutiveDiscontinuityLength, consecutiveDiscontinuityLength)
            } else {
                consecutiveDiscontinuityLength = 0.0
            }
        }

        val ccs = sumContributions / (totalPlannedLength + epsilon)

        // Check consecutive discontinuity
        if (maxConsecutiveDiscontinuityLength > lReview) {
            return CalculationResult(
                ccs,
                OutputClass.NEEDS_REVIEW,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Consecutive discontinuity length ($maxConsecutiveDiscontinuityLength m) exceeds L_review ($lReview m)")
            )
        }

        return CalculationResult(
            ccs,
            OutputClass.ADVISORY_ONLY,
            reviewState = ReviewState.NOT_REQUIRED,
            reasons = listOf("CCS calculated successfully")
        )
    }

    data class CorridorSegmentData(
        val segmentLength: Double,
        val shadeQuality: Double,
        val surfaceQuality: Double,
        val accessibilityQuality: Double,
        val safetyQuality: Double,
        val maintenanceQuality: Double
    )

    /**
     * Calculate automation safety margin index.
     * m_i = clamp(distanceToSafeBoundary / max(designDistance, epsilon), 0, 1)
     * ASMI_raw = minimum(m_i)
     * ASMI_protected = minimum(m_i * (1 - uncertainty_i) * (1 - severity_i))
     */
    @JvmStatic
    fun calculateAutomationSafetyMargin(desc: AutomationConditionDescriptor): CalculationResult<Double> {
        val reasons = mutableListOf<String>()

        // Validate human proximity state
        if (desc.humanProximityState.isBlank()) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("human_proximity_state is required"))
        }

        // Unknown proximity during hazardous action -> FAIL_SAFE_MODE
        if (desc.humanProximityState.equals("unknown", ignoreCase = true)) {
            return CalculationResult(
                null,
                OutputClass.INSUFFICIENT_EVIDENCE,
                automationState = AutomationState.FAIL_SAFE_MODE,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Unknown human proximity - fail-safe mode required for hazardous action")
            )
        }

        // Person in protective zone
        if (desc.humanProximityState.equals("in_protective_zone", ignoreCase = true) ||
            desc.humanProximityState.equals("person_detected", ignoreCase = true)) {
            return CalculationResult(
                null,
                OutputClass.NEEDS_REVIEW,
                automationState = AutomationState.REDUCE_AUTOMATION,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Person detected in protective zone - reduce automation or fail-safe mode")
            )
        }

        // Calculate per-condition margins
        val protectedMargins = mutableListOf<Double>()
        
        for (condition in desc.criticalConditions) {
            val distance = desc.observationValues[condition] ?: return CalculationResult(
                null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Missing observation value for condition: $condition")
            )
            val designDistance = desc.designDistanceValues[condition] ?: return CalculationResult(
                null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Missing design_distance for condition: $condition")
            )
            val uncertainty = desc.uncertaintyValues[condition] ?: return CalculationResult(
                null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Missing uncertainty for condition: $condition")
            )
            val severity = desc.severityValues[condition] ?: return CalculationResult(
                null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("Missing severity for condition: $condition")
            )

            // Validate ranges
            if (designDistance <= desc.epsilon) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("design_distance for $condition must be positive"))
            }
            if (uncertainty < 0 || uncertainty > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("uncertainty for $condition must be in [0, 1]"))
            }
            if (severity < 0 || severity > 1) {
                return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                    reasons = listOf("severity for $condition must be in [0, 1]"))
            }

            val mRaw = clamp(distance / maxOf(designDistance, desc.epsilon), 0.0, 1.0)
            val mProtected = mRaw * (1.0 - uncertainty) * (1.0 - severity)
            protectedMargins.add(mProtected)
        }

        if (protectedMargins.isEmpty()) {
            return CalculationResult(null, OutputClass.INSUFFICIENT_EVIDENCE,
                reasons = listOf("No critical conditions provided"))
        }

        val asmiProtected = protectedMargins.minOrNull() ?: 0.0

        // Status rules
        return when {
            asmiProtected < 0.1 -> CalculationResult(
                asmiProtected,
                OutputClass.INSUFFICIENT_EVIDENCE,
                automationState = AutomationState.FAIL_SAFE_MODE,
                reviewState = ReviewState.PENDING,
                reasons = listOf("ASMI_protected ($asmiProtected) below 0.1 - fail-safe mode required")
            )
            asmiProtected < 0.3 -> CalculationResult(
                asmiProtected,
                OutputClass.NEEDS_REVIEW,
                automationState = AutomationState.REDUCE_AUTOMATION,
                reviewState = ReviewState.PENDING,
                reasons = listOf("ASMI_protected ($asmiProtected) between 0.1 and 0.3 - reduce automation required")
            )
            else -> CalculationResult(
                asmiProtected,
                OutputClass.ADVISORY_ONLY,
                automationState = AutomationState.BOUNDED_AUTOMATION_ELIGIBLE,
                reviewState = ReviewState.NOT_REQUIRED,
                reasons = listOf("ASMI_protected ($asmiProtected) supports bounded automation eligibility")
            )
        }
    }

    /**
     * Evaluate conformance for a metric against evidence and gate state.
     * Decision order preserves non-compensatory protections.
     */
    @JvmStatic
    fun evaluateConformance(
        metricDefinition: MetricDefinition,
        evidenceDescriptor: EvidenceDescriptor,
        gateState: GateState,
        calculationResult: CalculationResult<*>
    ): ConformanceDecision {
        val reasons = mutableListOf<String>()

        // 1. Check for prohibited requests (person scoring, etc.)
        if (gateState.requiresPersonScoring || 
            gateState.requiresServiceEligibility ||
            gateState.requiresIdentityResolution ||
            gateState.requiresBiometricIdentification ||
            gateState.requiresCyberneticStatusAssessment ||
            gateState.requiresBehaviorProfiling) {
            return ConformanceDecision(
                outputClass = OutputClass.BLOCKED_BY_POLICY,
                metricName = metricDefinition.metricName,
                reasons = listOf("Request implies prohibited processing: person scoring, service eligibility, identity resolution, biometric identification, behavior profiling, or cybernetic-status assessment")
            )
        }

        // 2. Check governance protections
        val govErrors = MetricRegistryLoader.validateLocalMetricContract(metricDefinition)
        if (govErrors.isNotEmpty()) {
            return ConformanceDecision(
                outputClass = OutputClass.BLOCKED_BY_POLICY,
                metricName = metricDefinition.metricName,
                reasons = govErrors.map { "Governance violation: $it" }
            )
        }

        // 3. Check evidence state
        when (evidenceDescriptor.evidenceState) {
            EvidenceState.INSUFFICIENT_EVIDENCE -> {
                return ConformanceDecision(
                    outputClass = OutputClass.INSUFFICIENT_EVIDENCE,
                    metricName = metricDefinition.metricName,
                    reviewState = ReviewState.PENDING,
                    reasons = listOf("Evidence state is INSUFFICIENT_EVIDENCE")
                )
            }
            EvidenceState.CONFLICTED -> {
                return ConformanceDecision(
                    outputClass = OutputClass.CONFLICTED,
                    metricName = metricDefinition.metricName,
                    reviewState = ReviewState.PENDING,
                    reasons = listOf("Evidence contains conflicts")
                )
            }
            EvidenceState.STALE -> {
                return ConformanceDecision(
                    outputClass = OutputClass.NEEDS_REVIEW,
                    metricName = metricDefinition.metricName,
                    reviewState = ReviewState.PENDING,
                    reasons = listOf("Evidence is stale beyond declared validity limit")
                )
            }
            else -> {}
        }

        // Check evidence compatibility
        if (evidenceDescriptor.isCompatible == EvidenceCompatibility.INCOMPATIBLE) {
            return ConformanceDecision(
                outputClass = OutputClass.INSUFFICIENT_EVIDENCE,
                metricName = metricDefinition.metricName,
                reasons = listOf("Evidence is incompatible with metric requirements")
            )
        }

        // Check for conflicts
        if (evidenceDescriptor.hasConflict) {
            return ConformanceDecision(
                outputClass = OutputClass.CONFLICTED,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Evidence contains conflicts that must be resolved")
            )
        }

        // Check zero quality
        if (evidenceDescriptor.qualityScore <= 0) {
            return ConformanceDecision(
                outputClass = OutputClass.INSUFFICIENT_EVIDENCE,
                metricName = metricDefinition.metricName,
                reasons = listOf("Evidence quality score is zero")
            )
        }

        // 4. Check accessibility, rights alignment, consent, human review gates
        if (!gateState.accessibilityGatePassed) {
            return ConformanceDecision(
                outputClass = OutputClass.NEEDS_REVIEW,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Accessibility gate failed - human review required")
            )
        }

        if (!gateState.rightsAlignmentGatePassed) {
            return ConformanceDecision(
                outputClass = OutputClass.NEEDS_REVIEW,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Rights alignment gate failed - human review required")
            )
        }

        if (!gateState.consentGatePassed) {
            return ConformanceDecision(
                outputClass = OutputClass.NEEDS_REVIEW,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Consent gate failed - human review required")
            )
        }

        if (!gateState.humanReviewGatePassed) {
            return ConformanceDecision(
                outputClass = OutputClass.NEEDS_REVIEW,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = listOf("Human review gate failed - review required")
            )
        }

        // 5. Preserve metric-specific protective states
        if (calculationResult.automationState != null) {
            when (calculationResult.automationState) {
                AutomationState.FAIL_SAFE_MODE -> {
                    return ConformanceDecision(
                        outputClass = OutputClass.NEEDS_REVIEW,
                        automationState = AutomationState.FAIL_SAFE_MODE,
                        metricName = metricDefinition.metricName,
                        reviewState = ReviewState.PENDING,
                        reasons = calculationResult.reasons + listOf("Automation fail-safe state preserved")
                    )
                }
                AutomationState.REDUCE_AUTOMATION -> {
                    return ConformanceDecision(
                        outputClass = OutputClass.NEEDS_REVIEW,
                        automationState = AutomationState.REDUCE_AUTOMATION,
                        metricName = metricDefinition.metricName,
                        reviewState = ReviewState.PENDING,
                        reasons = calculationResult.reasons + listOf("Reduce automation state preserved")
                    )
                }
                else -> {}
            }
        }

        if (calculationResult.reviewState == ReviewState.PENDING) {
            return ConformanceDecision(
                outputClass = OutputClass.NEEDS_REVIEW,
                metricName = metricDefinition.metricName,
                reviewState = ReviewState.PENDING,
                reasons = calculationResult.reasons + listOf("Priority review state preserved")
            )
        }

        // 6. Otherwise: ADVISORY_ONLY
        return ConformanceDecision(
            outputClass = OutputClass.ADVISORY_ONLY,
            metricName = metricDefinition.metricName,
            reviewState = ReviewState.NOT_REQUIRED,
            reasons = calculationResult.reasons
        )
    }
}
