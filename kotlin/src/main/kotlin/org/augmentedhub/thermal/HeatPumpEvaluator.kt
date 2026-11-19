package org.augmentedhub.thermal

import java.time.Duration
import java.time.Instant
import java.util.ArrayDeque

enum class HeatPumpMode {
    HEATING,
    COOLING,
    ABSORPTION_CHILLING
}

data class HeatPumpSample(
    val observedAt: Instant,
    val mode: HeatPumpMode,
    val inputPowerKw: Double,
    val deliveredHeatKw: Double?,
    val removedHeatKw: Double?,
    val driveHeatKw: Double?
)

data class CopSample(
    val observedAt: Instant,
    val instantaneousCop: Double
)

data class HeatPumpEvaluation(
    val instantaneousCop: Double,
    val rollingAverageCop: Double,
    val corridorPermitted: Boolean,
    val explanationCode: String,
    val reviewRequired: Boolean
)

class HeatPumpEvaluator(
    private val minimumCop: Double,
    private val rollingWindow: Duration = Duration.ofMinutes(15)
) {
    private val samples = ArrayDeque<CopSample>()

    init {
        require(minimumCop.isFinite() && minimumCop > 0.0) {
            "minimumCop must be finite and greater than zero."
        }

        require(!rollingWindow.isNegative && !rollingWindow.isZero) {
            "rollingWindow must be greater than zero."
        }
    }

    fun evaluate(sample: HeatPumpSample): HeatPumpEvaluation {
        validateSample(sample)

        val instantaneousCop = calculateCop(sample)
        val cutoff = sample.observedAt.minus(rollingWindow)

        while (
            samples.isNotEmpty() &&
            samples.first().observedAt.isBefore(cutoff)
        ) {
            samples.removeFirst()
        }

        samples.addLast(
            CopSample(
                observedAt = sample.observedAt,
                instantaneousCop = instantaneousCop
            )
        )

        val rollingAverage = samples
            .map { it.instantaneousCop }
            .average()

        val instantaneousBelowMinimum = instantaneousCop < minimumCop
        val rollingBelowMinimum = rollingAverage < minimumCop

        return when {
            rollingBelowMinimum -> HeatPumpEvaluation(
                instantaneousCop = instantaneousCop,
                rollingAverageCop = rollingAverage,
                corridorPermitted = false,
                explanationCode = "ROLLING_COP_BELOW_MINIMUM_FAIL_CLOSED",
                reviewRequired = true
            )

            instantaneousBelowMinimum -> HeatPumpEvaluation(
                instantaneousCop = instantaneousCop,
                rollingAverageCop = rollingAverage,
                corridorPermitted = false,
                explanationCode = "INSTANTANEOUS_COP_BELOW_MINIMUM_FAIL_CLOSED",
                reviewRequired = true
            )

            else -> HeatPumpEvaluation(
                instantaneousCop = instantaneousCop,
                rollingAverageCop = rollingAverage,
                corridorPermitted = true,
                explanationCode = "HEAT_PUMP_COP_WITHIN_CORRIDOR",
                reviewRequired = false
            )
        }
    }

    private fun calculateCop(sample: HeatPumpSample): Double =
        when (sample.mode) {
            HeatPumpMode.HEATING ->
                requireNotNull(sample.deliveredHeatKw) {
                    "deliveredHeatKw is required in heating mode."
                } / sample.inputPowerKw

            HeatPumpMode.COOLING ->
                requireNotNull(sample.removedHeatKw) {
                    "removedHeatKw is required in cooling mode."
                } / sample.inputPowerKw

            HeatPumpMode.ABSORPTION_CHILLING ->
                requireNotNull(sample.removedHeatKw) {
                    "removedHeatKw is required in absorption-chilling mode."
                } / requireNotNull(sample.driveHeatKw) {
                    "driveHeatKw is required in absorption-chilling mode."
                }
        }

    private fun validateSample(sample: HeatPumpSample) {
        require(sample.inputPowerKw.isFinite() && sample.inputPowerKw > 0.0) {
            "inputPowerKw must be finite and greater than zero."
        }

        require(sample.deliveredHeatKw == null ||
            (sample.deliveredHeatKw.isFinite() && sample.deliveredHeatKw >= 0.0)
        ) {
            "deliveredHeatKw must be null or finite and non-negative."
        }

        require(sample.removedHeatKw == null ||
            (sample.removedHeatKw.isFinite() && sample.removedHeatKw >= 0.0)
        ) {
            "removedHeatKw must be null or finite and non-negative."
        }

        require(sample.driveHeatKw == null ||
            (sample.driveHeatKw.isFinite() && sample.driveHeatKw > 0.0)
        ) {
            "driveHeatKw must be null or finite and greater than zero."
        }
    }
}
