package cyboquatics

import kotlin.math.abs
import kotlin.math.max

object CecTrendIndicator {
    enum class Decision {
        CEC_WITHIN_CONFIGURED_TREND_BAND,
        CEC_TREND_REVIEW_REQUIRED,
        CEC_INSUFFICIENT_EVIDENCE,
        REJECTED_INPUT
    }

    data class Input(
        val currentCec: Double,
        val priorValidCecValues: List<Double>,
        val measurementQuality: Double,
        val minimumMeasurementQuality: Double,
        val minimumPriorObservationCount: Int,
        val denominatorFloor: Double,
        val configuredDeviationThreshold: Double,
        val extractionMethod: String,
        val unit: String,
        val samplingDepthDeclared: Boolean,
        val sampleHandlingDeclared: Boolean
    )

    data class Result(
        val decision: Decision,
        val rollingMedian: Double?,
        val relativeDeviation: Double?,
        val qualityWeightedDeviation: Double?,
        val reasons: List<String>
    )

    fun evaluate(input: Input): Result {
        if (
            !input.currentCec.isFinite() ||
            input.priorValidCecValues.any { !it.isFinite() } ||
            input.measurementQuality !in 0.0..1.0 ||
            input.minimumMeasurementQuality !in 0.0..1.0 ||
            input.minimumPriorObservationCount < 1 ||
            !input.denominatorFloor.isFinite() ||
            input.denominatorFloor <= 0.0 ||
            !input.configuredDeviationThreshold.isFinite() ||
            input.configuredDeviationThreshold < 0.0 ||
            input.extractionMethod.isBlank() ||
            input.unit.isBlank()
        ) {
            return Result(
                Decision.REJECTED_INPUT,
                null,
                null,
                null,
                listOf("CEC input, configuration, method, or unit is invalid.")
            )
        }

        if (
            input.priorValidCecValues.size < input.minimumPriorObservationCount ||
            input.measurementQuality < input.minimumMeasurementQuality ||
            !input.samplingDepthDeclared ||
            !input.sampleHandlingDeclared
        ) {
            return Result(
                Decision.CEC_INSUFFICIENT_EVIDENCE,
                null,
                null,
                null,
                listOf("Baseline count, quality evidence, sampling depth, or sample handling is insufficient.")
            )
        }

        val sorted = input.priorValidCecValues.sorted()
        val middle = sorted.size / 2
        val median = if (sorted.size % 2 == 1) {
            sorted[middle]
        } else {
            (sorted[middle - 1] + sorted[middle]) / 2.0
        }
        val relativeDeviation = abs(input.currentCec - median) / max(abs(median), input.denominatorFloor)
        val qualityWeightedDeviation = relativeDeviation * input.measurementQuality

        return if (qualityWeightedDeviation > input.configuredDeviationThreshold) {
            Result(
                Decision.CEC_TREND_REVIEW_REQUIRED,
                median,
                relativeDeviation,
                qualityWeightedDeviation,
                listOf("Quality-weighted deviation exceeds the configured review threshold.")
            )
        } else {
            Result(
                Decision.CEC_WITHIN_CONFIGURED_TREND_BAND,
                median,
                relativeDeviation,
                qualityWeightedDeviation,
                listOf("CEC is within the configured evidence-quality trend band.")
            )
        }
    }
}
