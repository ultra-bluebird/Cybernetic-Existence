package augmentedhub.emc

import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

enum class EmcSourceClass {
    UTILITY_DISTRIBUTION,
    TRANSIT_TRACTION,
    TRANSIT_STATION_EQUIPMENT,
    PUBLIC_WIRELESS_INFRASTRUCTURE,
    PUBLIC_CHARGING_EQUIPMENT,
    PUBLIC_BUILDING_EQUIPMENT,
    MIXED_PUBLIC_INFRASTRUCTURE,
    UNKNOWN
}

enum class FieldAssessmentState {
    ROUTINE_MONITORING,
    MONITORING_PRIORITY,
    ENGINEERING_REVIEW_PRIORITY,
    INSUFFICIENT_MEASUREMENT_CONFIDENCE
}

data class BandMeasurement(
    val bandName: String,
    val frequencyHz: Double,
    val measuredFieldValue: Double,
    val planningReferenceValue: Double,
    val bandWeight: Double,
    val standardUncertainty: Double,
    val dataQualityConfidence: Double,
    val sourceClass: EmcSourceClass,
    val calibrationCurrent: Boolean,
    val interpolated: Boolean,
    val interpolationStandardDeviation: Double?
) {
    fun validate(): BandMeasurement {
        require(bandName.isNotBlank()) {
            "bandName must not be blank."
        }
        require(frequencyHz.isFinite() && frequencyHz > 0.0) {
            "frequencyHz must be finite and positive."
        }
        require(measuredFieldValue.isFinite() && measuredFieldValue >= 0.0) {
            "measuredFieldValue must be finite and non-negative."
        }
        require(planningReferenceValue.isFinite() && planningReferenceValue > 0.0) {
            "planningReferenceValue must be finite and positive."
        }
        require(bandWeight.isFinite() && bandWeight >= 0.0) {
            "bandWeight must be finite and non-negative."
        }
        require(standardUncertainty.isFinite() && standardUncertainty >= 0.0) {
            "standardUncertainty must be finite and non-negative."
        }
        require(dataQualityConfidence in 0.0..1.0) {
            "dataQualityConfidence must be between 0 and 1."
        }

        if (interpolated) {
            require(
                interpolationStandardDeviation != null &&
                    interpolationStandardDeviation.isFinite() &&
                    interpolationStandardDeviation >= 0.0
            ) {
                "Interpolated measurements require a non-negative interpolation standard deviation."
            }
        }

        return this
    }
}

data class FieldAssessment(
    val indexValue: Double?,
    val standardUncertainty: Double?,
    val state: FieldAssessmentState,
    val explanation: String,
    val medicalCompatibilityClaimAllowed: Boolean,
    val individualRiskPredictionAllowed: Boolean,
    val propertyRankingAllowed: Boolean
)

object UrbanEmcFieldAssessment {
    fun assess(measurements: List<BandMeasurement>): FieldAssessment {
        require(measurements.isNotEmpty()) {
            "At least one calibrated band measurement is required."
        }

        measurements.forEach { it.validate() }

        if (measurements.any { !it.calibrationCurrent }) {
            return insufficient(
                "At least one measurement has no current calibration record."
            )
        }

        val totalWeight = measurements.sumOf { it.bandWeight }

        if (totalWeight <= 0.0) {
            return insufficient(
                "At least one band must have a positive published planning weight."
            )
        }

        var weightedIndex = 0.0
        var variance = 0.0
        var qualityWeight = 0.0

        for (measurement in measurements) {
            val normalized = min(
                1.0,
                max(
                    0.0,
                    measurement.measuredFieldValue / measurement.planningReferenceValue
                )
            )

            val contribution =
                measurement.bandWeight *
                    normalized *
                    measurement.dataQualityConfidence

            weightedIndex += contribution
            qualityWeight += measurement.bandWeight * measurement.dataQualityConfidence

            val normalizedUncertainty =
                measurement.standardUncertainty / measurement.planningReferenceValue

            val interpolationUncertainty =
                if (measurement.interpolated) {
                    measurement.interpolationStandardDeviation!! /
                        measurement.planningReferenceValue
                } else {
                    0.0
                }

            val totalNormalizedUncertainty =
                sqrt(
                    normalizedUncertainty * normalizedUncertainty +
                        interpolationUncertainty * interpolationUncertainty
                )

            variance +=
                measurement.bandWeight *
                    measurement.bandWeight *
                    totalNormalizedUncertainty *
                    totalNormalizedUncertainty
        }

        if (qualityWeight <= 0.0) {
            return insufficient(
                "Measurement quality confidence is insufficient for a planning index."
            )
        }

        val index = min(1.0, weightedIndex / qualityWeight)
        val uncertainty = sqrt(variance) / totalWeight
        val meanConfidence = qualityWeight / totalWeight

        val state = when {
            meanConfidence < 0.5 ->
                FieldAssessmentState.INSUFFICIENT_MEASUREMENT_CONFIDENCE
            index >= 0.8 ->
                FieldAssessmentState.ENGINEERING_REVIEW_PRIORITY
            index >= 0.4 ->
                FieldAssessmentState.MONITORING_PRIORITY
            else ->
                FieldAssessmentState.ROUTINE_MONITORING
        }

        val explanation = when (state) {
            FieldAssessmentState.INSUFFICIENT_MEASUREMENT_CONFIDENCE ->
                "Measurement confidence is limited. Additional calibrated observations are required."
            FieldAssessmentState.ENGINEERING_REVIEW_PRIORITY ->
                "Measured field conditions meet the published infrastructure-review threshold. This is not a medical-device compatibility or personal-risk conclusion."
            FieldAssessmentState.MONITORING_PRIORITY ->
                "Measured field conditions warrant scheduled monitoring under the published planning policy. This is not a medical-device compatibility or personal-risk conclusion."
            FieldAssessmentState.ROUTINE_MONITORING ->
                "Measured field conditions are within the current planning range. This is not a guarantee of compatibility with any individual device."
        }

        return FieldAssessment(
            indexValue = index,
            standardUncertainty = uncertainty,
            state = state,
            explanation = explanation,
            medicalCompatibilityClaimAllowed = false,
            individualRiskPredictionAllowed = false,
            propertyRankingAllowed = false
        )
    }

    private fun insufficient(explanation: String): FieldAssessment {
        return FieldAssessment(
            indexValue = null,
            standardUncertainty = null,
            state = FieldAssessmentState.INSUFFICIENT_MEASUREMENT_CONFIDENCE,
            explanation = explanation,
            medicalCompatibilityClaimAllowed = false,
            individualRiskPredictionAllowed = false,
            propertyRankingAllowed = false
        )
    }
}
