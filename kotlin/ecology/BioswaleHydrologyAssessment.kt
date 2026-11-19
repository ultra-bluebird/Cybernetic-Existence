package augmentedhub.ecology

import kotlin.math.max
import kotlin.math.sqrt

enum class DataQualityState {
    VALID,
    SENSOR_STALE,
    SENSOR_FAULT,
    CALIBRATION_EXPIRED,
    INCOMPLETE_EVENT,
    REQUIRES_HYDROLOGY_REVIEW
}

enum class HydrologyAssessmentState {
    REPORTABLE,
    INSUFFICIENT_EVIDENCE,
    HUMAN_REVIEW_REQUIRED
}

data class VolumeMeasurement(
    val cubicMeters: Double,
    val standardUncertaintyCubicMeters: Double
) {
    fun validate(name: String): VolumeMeasurement {
        require(cubicMeters.isFinite()) {
            "$name cubicMeters must be finite."
        }
        require(standardUncertaintyCubicMeters.isFinite() && standardUncertaintyCubicMeters >= 0.0) {
            "$name standard uncertainty must be finite and non-negative."
        }
        return this
    }
}

data class BioswaleStormEvent(
    val eventId: String,
    val inflow: VolumeMeasurement,
    val outflow: VolumeMeasurement,
    val overflow: VolumeMeasurement,
    val storageChange: VolumeMeasurement,
    val rainfallDepthMillimeters: Double,
    val dataQualityState: DataQualityState,
    val sensorCalibrationCurrent: Boolean,
    val humanHydrologyReviewCompleted: Boolean
) {
    fun validate(): BioswaleStormEvent {
        require(eventId.matches(Regex("^bioswale-event-[a-z0-9-]{4,95}$"))) {
            "eventId must use the bioswale-event identifier format."
        }

        inflow.validate("inflow")
        outflow.validate("outflow")
        overflow.validate("overflow")
        storageChange.validate("storageChange")

        require(rainfallDepthMillimeters.isFinite() && rainfallDepthMillimeters >= 0.0) {
            "rainfallDepthMillimeters must be finite and non-negative."
        }

        return this
    }
}

data class HydrologyAssessment(
    val state: HydrologyAssessmentState,
    val retainedVolumeCubicMeters: Double?,
    val retentionEfficiency: Double?,
    val standardUncertaintyCubicMeters: Double?,
    val explanation: String,
    val individualDataUsed: Boolean,
    val rawAudioUsed: Boolean,
    val externalExportAllowed: Boolean
)

object BioswaleHydrologyAssessment {
    fun assess(event: BioswaleStormEvent): HydrologyAssessment {
        event.validate()

        if (event.dataQualityState != DataQualityState.VALID) {
            return insufficient(
                "Event data quality is ${event.dataQualityState}; benefit reporting requires validated hydrology evidence."
            )
        }

        if (!event.sensorCalibrationCurrent) {
            return insufficient(
                "Sensor calibration is not current; retained-volume reporting is withheld."
            )
        }

        val retained = event.inflow.cubicMeters -
            event.outflow.cubicMeters -
            event.overflow.cubicMeters -
            event.storageChange.cubicMeters

        val uncertainty = sqrt(
            event.inflow.standardUncertaintyCubicMeters *
                event.inflow.standardUncertaintyCubicMeters +
                event.outflow.standardUncertaintyCubicMeters *
                    event.outflow.standardUncertaintyCubicMeters +
                event.overflow.standardUncertaintyCubicMeters *
                    event.overflow.standardUncertaintyCubicMeters +
                event.storageChange.standardUncertaintyCubicMeters *
                    event.storageChange.standardUncertaintyCubicMeters
        )

        if (retained < 0.0) {
            return HydrologyAssessment(
                state = HydrologyAssessmentState.HUMAN_REVIEW_REQUIRED,
                retainedVolumeCubicMeters = null,
                retentionEfficiency = null,
                standardUncertaintyCubicMeters = uncertainty,
                explanation = "Calculated retained volume is negative. Review outflow, overflow, storage change, event boundaries, and sensor calibration.",
                individualDataUsed = false,
                rawAudioUsed = false,
                externalExportAllowed = false
            )
        }

        if (!event.humanHydrologyReviewCompleted) {
            return HydrologyAssessment(
                state = HydrologyAssessmentState.HUMAN_REVIEW_REQUIRED,
                retainedVolumeCubicMeters = retained,
                retentionEfficiency = null,
                standardUncertaintyCubicMeters = uncertainty,
                explanation = "A calculated event estimate exists, but qualified hydrology review has not been recorded.",
                individualDataUsed = false,
                rawAudioUsed = false,
                externalExportAllowed = false
            )
        }

        val efficiency = retained / max(event.inflow.cubicMeters, 1.0e-9)

        return HydrologyAssessment(
            state = HydrologyAssessmentState.REPORTABLE,
            retainedVolumeCubicMeters = retained,
            retentionEfficiency = efficiency,
            standardUncertaintyCubicMeters = uncertainty,
            explanation = "Event retained volume was calculated from measured inflow, outflow, overflow, and storage change with first-order propagated uncertainty.",
            individualDataUsed = false,
            rawAudioUsed = false,
            externalExportAllowed = false
        )
    }

    private fun insufficient(explanation: String): HydrologyAssessment {
        return HydrologyAssessment(
            state = HydrologyAssessmentState.INSUFFICIENT_EVIDENCE,
            retainedVolumeCubicMeters = null,
            retentionEfficiency = null,
            standardUncertaintyCubicMeters = null,
            explanation = explanation,
            individualDataUsed = false,
            rawAudioUsed = false,
            externalExportAllowed = false
        )
    }
}
