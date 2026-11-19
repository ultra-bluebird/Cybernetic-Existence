package org.augmentedhub.cyboquatic

import java.math.BigDecimal
import java.math.RoundingMode

enum class DrainageMeasure {
    BOD,
    TSS,
    CEC
}

data class ReferenceRange(
    val lower: BigDecimal,
    val upper: BigDecimal
) {
    init {
        require(lower >= BigDecimal.ZERO) { "lower reference must be non-negative" }
        require(upper > lower) { "upper reference must exceed lower reference" }
    }
}

data class RawDrainageMeasurement(
    val observationId: Long,
    val measure: DrainageMeasure,
    val value: BigDecimal,
    val uncertaintyStdDev: BigDecimal,
    val qualityAccepted: Boolean
) {
    init {
        require(observationId > 0) { "observationId must be positive" }
        require(value >= BigDecimal.ZERO) { "value must be non-negative" }
        require(uncertaintyStdDev > BigDecimal.ZERO) { "uncertaintyStdDev must be positive" }
    }
}

sealed interface NormalizationResult {
    data class Included(
        val observationId: Long,
        val measure: DrainageMeasure,
        val normalizedValue: BigDecimal,
        val observationVariance: BigDecimal
    ) : NormalizationResult

    data class Excluded(
        val observationId: Long,
        val reason: String
    ) : NormalizationResult
}

object DrainageMeasurementNormalizer {
    private val one = BigDecimal.ONE
    private val zero = BigDecimal.ZERO

    fun normalize(
        measurement: RawDrainageMeasurement,
        range: ReferenceRange
    ): NormalizationResult {
        if (!measurement.qualityAccepted) {
            return NormalizationResult.Excluded(
                measurement.observationId,
                "raw observation is not accepted by its quality gate"
            )
        }

        val span = range.upper.subtract(range.lower)
        val normalized = measurement.value
            .subtract(range.lower)
            .divide(span, 12, RoundingMode.HALF_EVEN)
            .coerceIn(zero, one)

        val normalizedStdDev = measurement.uncertaintyStdDev
            .divide(span, 12, RoundingMode.HALF_EVEN)

        val variance = normalizedStdDev.multiply(normalizedStdDev)

        if (variance <= zero) {
            return NormalizationResult.Excluded(
                measurement.observationId,
                "normalized observation variance is not positive"
            )
        }

        return NormalizationResult.Included(
            observationId = measurement.observationId,
            measure = measurement.measure,
            normalizedValue = normalized,
            observationVariance = variance
        )
    }

    private fun BigDecimal.coerceIn(
        minimum: BigDecimal,
        maximum: BigDecimal
    ): BigDecimal = when {
        this < minimum -> minimum
        this > maximum -> maximum
        else -> this
    }
}
