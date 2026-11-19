package org.augmentedhub.sensors

/**
 * Canonical reference implementation for energy-efficient adaptive sensor polling.
 *
 * The polling interval is inversely proportional to the normalized recent
 * change-rate estimate:
 *
 * T_poll = T_base / (1 + alpha * r_change)
 *
 * The result is clamped to a configured minimum interval and maximum interval.
 * The minimum interval prevents excessive polling during rapid changes or noisy
 * measurements. The maximum interval preserves the required monitoring cadence
 * when measurements are stable.
 *
 * This function is deterministic, side-effect free, and advisory-only. It does
 * not read sensors, change a device configuration, transmit data, or actuate
 * hardware.
 */
object AdaptivePolling {
    /**
     * Calculates the next polling interval based on the rate of change.
     *
     * @param baseIntervalSeconds The nominal polling interval in seconds.
     * @param alpha The non-negative responsiveness parameter. A higher value
     * makes the interval shrink more rapidly when change rate increases.
     * @param changeRate The finite normalized recent change-rate estimate.
     * Must be greater than or equal to zero.
     * @param minIntervalSeconds The finite positive minimum polling interval.
     * This is the lower safety bound.
     * @param maxIntervalSeconds The finite polling interval upper bound.
     * This is the maximum cadence interval before a new observation is required.
     * @return The calculated polling interval in seconds, clamped inclusively to
     * the configured safe bounds.
     * @throws IllegalArgumentException When an input is non-finite, non-positive
     * where positivity is required, negative where non-negativity is required,
     * or when the configured interval bounds are invalid.
     */
    @JvmStatic
    fun calculateAdaptivePollInterval(
        baseIntervalSeconds: Double,
        alpha: Double,
        changeRate: Double,
        minIntervalSeconds: Double,
        maxIntervalSeconds: Double
    ): Double {
        requireFinitePositive(baseIntervalSeconds, "baseIntervalSeconds")
        requireFiniteNonNegative(alpha, "alpha")
        requireFiniteNonNegative(changeRate, "changeRate")
        requireFinitePositive(minIntervalSeconds, "minIntervalSeconds")
        requireFinitePositive(maxIntervalSeconds, "maxIntervalSeconds")

        require(maxIntervalSeconds >= minIntervalSeconds) {
            "maxIntervalSeconds must be greater than or equal to minIntervalSeconds"
        }

        val denominator = 1.0 + alpha * changeRate

        require(denominator.isFinite() && denominator > 0.0) {
            "1 + alpha * changeRate must be finite and positive"
        }

        val rawIntervalSeconds = baseIntervalSeconds / denominator

        return when {
            !rawIntervalSeconds.isFinite() -> minIntervalSeconds
            rawIntervalSeconds < minIntervalSeconds -> minIntervalSeconds
            rawIntervalSeconds > maxIntervalSeconds -> maxIntervalSeconds
            else -> rawIntervalSeconds
        }
    }

    /**
     * Calculates a bounded adaptive interval while preserving a mandatory maximum
     * monitoring cadence.
     *
     * The returned interval never exceeds [requiredMaximumIntervalSeconds], even
     * if [maxIntervalSeconds] is larger. This supports monitored environmental,
     * infrastructure, and public-information workflows that require observations
     * at least once within a documented maximum interval.
     *
     * @param requiredMaximumIntervalSeconds The maximum permitted elapsed time
     * between observations for the stated monitoring purpose.
     * @return A valid polling interval in seconds bounded by both configured and
     * required maximum cadence limits.
     */
    @JvmStatic
    fun calculateCadenceBoundedPollInterval(
        baseIntervalSeconds: Double,
        alpha: Double,
        changeRate: Double,
        minIntervalSeconds: Double,
        maxIntervalSeconds: Double,
        requiredMaximumIntervalSeconds: Double
    ): Double {
        requireFinitePositive(requiredMaximumIntervalSeconds, "requiredMaximumIntervalSeconds")

        val effectiveMaximumIntervalSeconds = minOf(
            maxIntervalSeconds,
            requiredMaximumIntervalSeconds
        )

        require(effectiveMaximumIntervalSeconds >= minIntervalSeconds) {
            "The effective maximum interval must be greater than or equal to minIntervalSeconds"
        }

        return calculateAdaptivePollInterval(
            baseIntervalSeconds = baseIntervalSeconds,
            alpha = alpha,
            changeRate = changeRate,
            minIntervalSeconds = minIntervalSeconds,
            maxIntervalSeconds = effectiveMaximumIntervalSeconds
        )
    }

    /**
     * Calculates normalized relative change between consecutive measurements.
     *
     * r_change = |x_current - x_previous| /
     *            max(|x_previous|, referenceScale, epsilon)
     *
     * @param currentValue The current finite measurement.
     * @param previousValue The previous finite measurement.
     * @param referenceScale A positive domain-specific scale that prevents
     * unstable relative-change values near zero.
     * @param epsilon A positive numerical stability value.
     * @return A finite non-negative normalized relative-change estimate.
     */
    @JvmStatic
    fun calculateRelativeChangeRate(
        currentValue: Double,
        previousValue: Double,
        referenceScale: Double,
        epsilon: Double
    ): Double {
        requireFinite(currentValue, "currentValue")
        requireFinite(previousValue, "previousValue")
        requireFinitePositive(referenceScale, "referenceScale")
        requireFinitePositive(epsilon, "epsilon")

        val denominator = maxOf(
            kotlin.math.abs(previousValue),
            referenceScale,
            epsilon
        )

        return kotlin.math.abs(currentValue - previousValue) / denominator
    }

    /**
     * Computes the median of a non-empty collection of finite, non-negative
     * change-rate values.
     *
     * A median is used to limit the effect of isolated sensor noise and reduce
     * unnecessary wake-up behavior.
     *
     * @param changeRates Recent normalized change-rate values.
     * @return The median normalized change rate.
     */
    @JvmStatic
    fun calculateRobustChangeRate(changeRates: Collection<Double>): Double {
        require(changeRates.isNotEmpty()) {
            "changeRates must contain at least one value"
        }

        val sortedRates = changeRates.mapIndexed { index, rate ->
            requireFiniteNonNegative(rate, "changeRates[$index]")
            rate
        }.sorted()

        val middle = sortedRates.size / 2

        return if (sortedRates.size % 2 == 1) {
            sortedRates[middle]
        } else {
            (sortedRates[middle - 1] + sortedRates[middle]) / 2.0
        }
    }

    /**
     * Returns whether a sensor should wake before its scheduled poll interval.
     *
     * This function only evaluates a local advisory condition. It does not wake
     * hardware or transmit data.
     *
     * @param absoluteChange Absolute measurement change in the variable's unit.
     * @param relativeChange Normalized relative change-rate estimate.
     * @param criticalAbsoluteChange Configured absolute-change wake threshold.
     * @param criticalRelativeChange Configured relative-change wake threshold.
     * @param safetyCorridorBreach Whether a separately evaluated safety corridor
     * requires review.
     * @param calibrationReviewNeeded Whether calibration or sensor-health review
     * is required.
     * @return True when an approved local condition indicates an earlier poll or
     * review should be scheduled.
     */
    @JvmStatic
    fun shouldWakeEarly(
        absoluteChange: Double,
        relativeChange: Double,
        criticalAbsoluteChange: Double,
        criticalRelativeChange: Double,
        safetyCorridorBreach: Boolean,
        calibrationReviewNeeded: Boolean
    ): Boolean {
        requireFiniteNonNegative(absoluteChange, "absoluteChange")
        requireFiniteNonNegative(relativeChange, "relativeChange")
        requireFiniteNonNegative(criticalAbsoluteChange, "criticalAbsoluteChange")
        requireFiniteNonNegative(criticalRelativeChange, "criticalRelativeChange")

        return absoluteChange > criticalAbsoluteChange ||
            relativeChange > criticalRelativeChange ||
            safetyCorridorBreach ||
            calibrationReviewNeeded
    }

    /**
     * Estimates energy used during one sensor polling cycle.
     *
     * E_cycle = V * sum(I_stage * t_stage)
     *
     * Current must be supplied in amperes, duration in seconds, voltage in volts,
     * and the returned energy is in joules.
     *
     * @param voltageVolts Supply voltage in volts.
     * @param sleepCurrentAmps Sleep-state current in amperes.
     * @param sleepDurationSeconds Sleep-state duration in seconds.
     * @param wakeCurrentAmps Wake-state current in amperes.
     * @param wakeDurationSeconds Wake-state duration in seconds.
     * @param sensingCurrentAmps Sensor measurement current in amperes.
     * @param sensingDurationSeconds Sensor measurement duration in seconds.
     * @param computeCurrentAmps Local computation current in amperes.
     * @param computeDurationSeconds Local computation duration in seconds.
     * @param storageCurrentAmps Local storage current in amperes.
     * @param storageDurationSeconds Local storage duration in seconds.
     * @param transmissionCurrentAmps Approved transmission current in amperes.
     * @param transmissionDurationSeconds Transmission duration in seconds.
     * @return Estimated cycle energy use in joules.
     */
    @JvmStatic
    fun calculateCycleEnergyJoules(
        voltageVolts: Double,
        sleepCurrentAmps: Double,
        sleepDurationSeconds: Double,
        wakeCurrentAmps: Double,
        wakeDurationSeconds: Double,
        sensingCurrentAmps: Double,
        sensingDurationSeconds: Double,
        computeCurrentAmps: Double,
        computeDurationSeconds: Double,
        storageCurrentAmps: Double,
        storageDurationSeconds: Double,
        transmissionCurrentAmps: Double,
        transmissionDurationSeconds: Double
    ): Double {
        requireFinitePositive(voltageVolts, "voltageVolts")

        val stages = listOf(
            EnergyStage(sleepCurrentAmps, sleepDurationSeconds, "sleep"),
            EnergyStage(wakeCurrentAmps, wakeDurationSeconds, "wake"),
            EnergyStage(sensingCurrentAmps, sensingDurationSeconds, "sensing"),
            EnergyStage(computeCurrentAmps, computeDurationSeconds, "compute"),
            EnergyStage(storageCurrentAmps, storageDurationSeconds, "storage"),
            EnergyStage(transmissionCurrentAmps, transmissionDurationSeconds, "transmission")
        )

        val chargeCoulombs = stages.sumOf { stage ->
            requireFiniteNonNegative(stage.currentAmps, "${stage.name}CurrentAmps")
            requireFiniteNonNegative(stage.durationSeconds, "${stage.name}DurationSeconds")
            stage.currentAmps * stage.durationSeconds
        }

        return voltageVolts * chargeCoulombs
    }

    /**
     * Tests whether a measured sleep current is below a configured target.
     *
     * @param sleepCurrentAmps Measured or documented sleep current in amperes.
     * @param targetMicroamps Positive target in microamperes.
     * @return True when sleep current is strictly lower than the target.
     */
    @JvmStatic
    fun sleepCurrentWithinTarget(
        sleepCurrentAmps: Double,
        targetMicroamps: Double = 10.0
    ): Boolean {
        requireFiniteNonNegative(sleepCurrentAmps, "sleepCurrentAmps")
        requireFinitePositive(targetMicroamps, "targetMicroamps")

        val targetAmps = targetMicroamps * MICROAMPS_TO_AMPS

        return sleepCurrentAmps < targetAmps
    }

    private data class EnergyStage(
        val currentAmps: Double,
        val durationSeconds: Double,
        val name: String
    )

    private fun requireFinite(value: Double, name: String) {
        require(value.isFinite()) {
            "$name must be finite"
        }
    }

    private fun requireFinitePositive(value: Double, name: String) {
        require(value.isFinite() && value > 0.0) {
            "$name must be finite and positive"
        }
    }

    private fun requireFiniteNonNegative(value: Double, name: String) {
        require(value.isFinite() && value >= 0.0) {
            "$name must be finite and non-negative"
        }
    }

    private const val MICROAMPS_TO_AMPS = 0.000001
}
