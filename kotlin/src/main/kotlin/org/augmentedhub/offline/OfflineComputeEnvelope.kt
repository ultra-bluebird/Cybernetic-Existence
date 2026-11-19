package org.augmentedhub.offline

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

enum class OfflineMode {
    OFFLINE_NORMAL,
    OFFLINE_CONSERVATION,
    OFFLINE_SAFE_HOLD
}

data class OfflineComputeInput(
    val availablePowerWatts: Double,
    val systemEfficiency: Double,
    val schedulingWindowSeconds: Double,
    val taskEnergyJoules: Double,
    val basePowerWatts: Double,
    val batteryEnergyJoules: Double,
    val batteryThresholdFraction: Double,
    val currentBatteryFraction: Double,
    val normalizedThermalLoad: Double,
    val environmentalDataQuality: Double
)

data class OfflineComputeEnvelope(
    val mode: OfflineMode,
    val estimatedTaskCapacity: Long,
    val estimatedRuntimeSeconds: Double,
    val recommendedBudgetFraction: Double,
    val explanation: String
)

object OfflineComputePlanner {
    fun evaluate(input: OfflineComputeInput): OfflineComputeEnvelope {
        validate(input)

        val totalPowerWatts =
            input.basePowerWatts + input.availablePowerWatts

        val estimatedRuntimeSeconds =
            (input.batteryEnergyJoules * input.systemEfficiency) /
                totalPowerWatts

        val rawTaskCapacity =
            (
                input.availablePowerWatts *
                    input.systemEfficiency *
                    input.schedulingWindowSeconds
            ) / input.taskEnergyJoules

        val mode = when {
            input.currentBatteryFraction < input.batteryThresholdFraction ->
                OfflineMode.OFFLINE_SAFE_HOLD

            input.normalizedThermalLoad > 0.75 ||
                input.environmentalDataQuality < 0.50 ->
                OfflineMode.OFFLINE_CONSERVATION

            else ->
                OfflineMode.OFFLINE_NORMAL
        }

        val recommendedBudgetFraction = when (mode) {
            OfflineMode.OFFLINE_NORMAL -> 1.0
            OfflineMode.OFFLINE_CONSERVATION -> 0.40
            OfflineMode.OFFLINE_SAFE_HOLD -> 0.0
        }

        val explanation = when (mode) {
            OfflineMode.OFFLINE_NORMAL ->
                "Local external-device tasks may continue within the configured battery and thermal envelope."

            OfflineMode.OFFLINE_CONSERVATION ->
                "Reduce nonessential external-device workload because heat or environmental data quality triggers conservation mode."

            OfflineMode.OFFLINE_SAFE_HOLD ->
                "Hold new external-device tasks, preserve the last valid local state, and avoid overwriting continuity records."
        }

        return OfflineComputeEnvelope(
            mode = mode,
            estimatedTaskCapacity = floor(
                max(rawTaskCapacity, 0.0) * recommendedBudgetFraction
            ).toLong(),
            estimatedRuntimeSeconds = max(estimatedRuntimeSeconds, 0.0),
            recommendedBudgetFraction = recommendedBudgetFraction,
            explanation = explanation
        )
    }

    private fun validate(input: OfflineComputeInput) {
        require(
            input.availablePowerWatts.isFinite() &&
                input.availablePowerWatts >= 0.0
        ) {
            "availablePowerWatts must be finite and non-negative."
        }

        require(
            input.systemEfficiency.isFinite() &&
                input.systemEfficiency in 0.0..1.0
        ) {
            "systemEfficiency must be within [0, 1]."
        }

        require(
            input.schedulingWindowSeconds.isFinite() &&
                input.schedulingWindowSeconds > 0.0
        ) {
            "schedulingWindowSeconds must be finite and greater than zero."
        }

        require(
            input.taskEnergyJoules.isFinite() &&
                input.taskEnergyJoules > 0.0
        ) {
            "taskEnergyJoules must be finite and greater than zero."
        }

        require(
            input.basePowerWatts.isFinite() &&
                input.basePowerWatts >= 0.0
        ) {
            "basePowerWatts must be finite and non-negative."
        }

        require(
            input.batteryEnergyJoules.isFinite() &&
                input.batteryEnergyJoules >= 0.0
        ) {
            "batteryEnergyJoules must be finite and non-negative."
        }

        val unitIntervalValues = listOf(
            input.batteryThresholdFraction,
            input.currentBatteryFraction,
            input.normalizedThermalLoad,
            input.environmentalDataQuality
        )

        require(unitIntervalValues.all { it.isFinite() && it in 0.0..1.0 }) {
            "Battery, thermal, and environmental quality fractions must be within [0, 1]."
        }
    }
}
