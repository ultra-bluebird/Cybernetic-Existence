package cyboquatics

import kotlin.math.max
import kotlin.math.min

object RecoveryAcceptanceFogMetrics {
    enum class HeatDecision {
        RECOVERY_ELIGIBLE_FOR_COMMUNITY_REVIEW,
        RECOVERY_HOLD_FOR_RIGHTS_REVIEW,
        INVALID_INPUT
    }

    enum class MediaRoute {
        KNOWN_MEDIA,
        FOG_REVIEW,
        INVALID_INPUT
    }

    data class HeatInputs(
        val nightAirTemperatureDeltaC: Double,
        val albedoDelta: Double,
        val canopyShadeFraction: Double,
        val evapotranspirationProxy: Double,
        val airflowObstructionFactor: Double,
        val targetNightCoolingC: Double,
        val displacementReported: Boolean,
        val rightsReviewAvailable: Boolean,
        val personalOrSensitiveTelemetryCollected: Boolean,
        val communityIdentityProtectionDocumented: Boolean
    )

    data class HeatResult(
        val decision: HeatDecision,
        val coolingPotential: Double,
        val observedNightCoolingScore: Double,
        val rightsGatePassed: Boolean,
        val reasons: List<String>
    )

    data class AcceptanceInputs(
        val completedResponses: Int,
        val anonymousLikertMean: Double,
        val policyComplianceRatio: Double,
        val appealResolutionRatio: Double,
        val validAppeals: Int,
        val coveredServicesOrDecisions: Int
    )

    data class AcceptanceResult(
        val publishable: Boolean,
        val acceptanceIndex: Double?,
        val appealRate: Double?,
        val reasons: List<String>
    )

    data class CanalMediaInputs(
        val declaredMediaClass: String,
        val approvedMediaClasses: Set<String>,
        val uncertaintyFlag: Boolean,
        val classificationConfidence: Double,
        val evidenceCompleteness: Double,
        val knowledgeFactor: Double,
        val chainOfCustodyComplete: Boolean,
        val calibrationRecordCurrent: Boolean,
        val retentionMetadataPresent: Boolean,
        val hazardFlagActive: Boolean
    )

    data class CanalMediaResult(
        val route: MediaRoute,
        val reasons: List<String>
    )

    fun evaluateHeat(inputs: HeatInputs): HeatResult {
        val valid = finite(inputs.nightAirTemperatureDeltaC) &&
            unit(inputs.albedoDelta) &&
            unit(inputs.canopyShadeFraction) &&
            unit(inputs.evapotranspirationProxy) &&
            unit(inputs.airflowObstructionFactor) &&
            finite(inputs.targetNightCoolingC) &&
            inputs.targetNightCoolingC > 0.0

        if (!valid) {
            return HeatResult(
                HeatDecision.INVALID_INPUT,
                0.0,
                0.0,
                false,
                listOf("Input values must be finite; normalized values must be within 0..1; target cooling must be positive.")
            )
        }

        val albedo = clamp01(inputs.albedoDelta / 0.25)
        val vegetation = clamp01(
            0.60 * inputs.canopyShadeFraction + 0.40 * inputs.evapotranspirationProxy
        )
        val airflow = clamp01(1.0 - inputs.airflowObstructionFactor)
        val coolingPotential = clamp01(0.25 * albedo + 0.55 * vegetation + 0.20 * airflow)
        val observedCooling = clamp01((-inputs.nightAirTemperatureDeltaC) / inputs.targetNightCoolingC)

        val reasons = mutableListOf<String>()
        if (inputs.displacementReported) reasons += "Project-caused displacement was reported."
        if (!inputs.rightsReviewAvailable) reasons += "Accessible community review is unavailable."
        if (inputs.personalOrSensitiveTelemetryCollected) reasons += "Personal or sensitive telemetry collection is prohibited."
        if (!inputs.communityIdentityProtectionDocumented) reasons += "Community identity protection is not documented."

        val rightsGatePassed = reasons.isEmpty()
        val decision = if (rightsGatePassed) {
            HeatDecision.RECOVERY_ELIGIBLE_FOR_COMMUNITY_REVIEW
        } else {
            HeatDecision.RECOVERY_HOLD_FOR_RIGHTS_REVIEW
        }

        return HeatResult(decision, coolingPotential, observedCooling, rightsGatePassed, reasons)
    }

    fun evaluateAcceptance(inputs: AcceptanceInputs): AcceptanceResult {
        val valid = inputs.completedResponses >= 0 &&
            inputs.validAppeals >= 0 &&
            inputs.coveredServicesOrDecisions > 0 &&
            finite(inputs.anonymousLikertMean) &&
            inputs.anonymousLikertMean in 1.0..5.0 &&
            unit(inputs.policyComplianceRatio) &&
            unit(inputs.appealResolutionRatio)

        if (!valid) {
            return AcceptanceResult(false, null, null, listOf("Invalid aggregate inputs."))
        }

        if (inputs.completedResponses < 30) {
            return AcceptanceResult(
                false,
                null,
                null,
                listOf("Suppressed: fewer than 30 voluntary responses.")
            )
        }

        val likert = clamp01((inputs.anonymousLikertMean - 1.0) / 4.0)
        val index = clamp01(
            0.50 * likert +
                0.30 * inputs.policyComplianceRatio +
                0.20 * inputs.appealResolutionRatio
        )
        val appealRate = inputs.validAppeals.toDouble() / inputs.coveredServicesOrDecisions.toDouble()

        return AcceptanceResult(
            true,
            index,
            appealRate,
            listOf("Appeal rate is reported separately and requires accessibility interpretation.")
        )
    }

    fun routeCanalMedia(inputs: CanalMediaInputs): CanalMediaResult {
        val valid = inputs.declaredMediaClass.isNotBlank() &&
            inputs.approvedMediaClasses.isNotEmpty() &&
            unit(inputs.classificationConfidence) &&
            unit(inputs.evidenceCompleteness) &&
            unit(inputs.knowledgeFactor)

        if (!valid) {
            return CanalMediaResult(MediaRoute.INVALID_INPUT, listOf("Invalid or incomplete routing inputs."))
        }

        val reasons = mutableListOf<String>()
        if (inputs.uncertaintyFlag) reasons += "Uncertainty flag is active."
        if (inputs.classificationConfidence < 0.70) reasons += "Classification confidence is below 0.70."
        if (inputs.evidenceCompleteness < 0.90) reasons += "Evidence completeness is below 0.90."
        if (inputs.knowledgeFactor < 0.70) reasons += "Knowledge factor is below 0.70."
        if (inputs.declaredMediaClass !in inputs.approvedMediaClasses) reasons += "Media class is not approved."
        if (!inputs.chainOfCustodyComplete) reasons += "Chain of custody is incomplete."
        if (!inputs.calibrationRecordCurrent) reasons += "Calibration record is absent or stale."
        if (!inputs.retentionMetadataPresent) reasons += "Retention metadata is absent."
        if (inputs.hazardFlagActive) reasons += "Hazard flag is active."

        return if (reasons.isEmpty()) {
            CanalMediaResult(MediaRoute.KNOWN_MEDIA, listOf("All review prerequisites passed."))
        } else {
            CanalMediaResult(MediaRoute.FOG_REVIEW, reasons)
        }
    }

    private fun finite(value: Double): Boolean = value.isFinite()

    private fun unit(value: Double): Boolean = finite(value) && value in 0.0..1.0

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
