package org.augmentedhub.sensors

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class AdaptivePollingTest {
    @Test
    fun returnsBaseIntervalWhenChangeRateIsZero() {
        val interval = AdaptivePolling.calculateAdaptivePollInterval(
            baseIntervalSeconds = 60.0,
            alpha = 2.0,
            changeRate = 0.0,
            minIntervalSeconds = 5.0,
            maxIntervalSeconds = 120.0
        )

        assertEquals(60.0, interval, absoluteTolerance = 0.0000001)
    }

    @Test
    fun reducesIntervalWhenChangeRateIncreases() {
        val interval = AdaptivePolling.calculateAdaptivePollInterval(
            baseIntervalSeconds = 60.0,
            alpha = 1.0,
            changeRate = 2.0,
            minIntervalSeconds = 5.0,
            maxIntervalSeconds = 120.0
        )

        assertEquals(20.0, interval, absoluteTolerance = 0.0000001)
    }

    @Test
    fun clampsToMinimumIntervalDuringRapidChange() {
        val interval = AdaptivePolling.calculateAdaptivePollInterval(
            baseIntervalSeconds = 60.0,
            alpha = 100.0,
            changeRate = 10.0,
            minIntervalSeconds = 5.0,
            maxIntervalSeconds = 120.0
        )

        assertEquals(5.0, interval, absoluteTolerance = 0.0000001)
    }

    @Test
    fun clampsToMaximumIntervalWhenBaseIntervalExceedsMaximum() {
        val interval = AdaptivePolling.calculateAdaptivePollInterval(
            baseIntervalSeconds = 300.0,
            alpha = 0.0,
            changeRate = 0.0,
            minIntervalSeconds = 5.0,
            maxIntervalSeconds = 120.0
        )

        assertEquals(120.0, interval, absoluteTolerance = 0.0000001)
    }

    @Test
    fun respectsRequiredMaximumCadence() {
        val interval = AdaptivePolling.calculateCadenceBoundedPollInterval(
            baseIntervalSeconds = 900.0,
            alpha = 0.0,
            changeRate = 0.0,
            minIntervalSeconds = 30.0,
            maxIntervalSeconds = 1200.0,
            requiredMaximumIntervalSeconds = 300.0
        )

        assertEquals(300.0, interval, absoluteTolerance = 0.0000001)
    }

    @Test
    fun rejectsNonFiniteInputs() {
        assertFailsWith<IllegalArgumentException> {
            AdaptivePolling.calculateAdaptivePollInterval(
                baseIntervalSeconds = Double.NaN,
                alpha = 1.0,
                changeRate = 1.0,
                minIntervalSeconds = 5.0,
                maxIntervalSeconds = 60.0
            )
        }

        assertFailsWith<IllegalArgumentException> {
            AdaptivePolling.calculateAdaptivePollInterval(
                baseIntervalSeconds = 60.0,
                alpha = Double.POSITIVE_INFINITY,
                changeRate = 1.0,
                minIntervalSeconds = 5.0,
                maxIntervalSeconds = 60.0
            )
        }
    }

    @Test
    fun rejectsInvalidBounds() {
        assertFailsWith<IllegalArgumentException> {
            AdaptivePolling.calculateAdaptivePollInterval(
                baseIntervalSeconds = 60.0,
                alpha = 1.0,
                changeRate = 1.0,
                minIntervalSeconds = 60.0,
                maxIntervalSeconds = 5.0
            )
        }
    }

    @Test
    fun calculatesRelativeChangeNearZeroUsingReferenceScale() {
        val changeRate = AdaptivePolling.calculateRelativeChangeRate(
            currentValue = 0.10,
            previousValue = 0.0,
            referenceScale = 1.0,
            epsilon = 0.000001
        )

        assertEquals(0.10, changeRate, absoluteTolerance = 0.0000001)
    }

    @Test
    fun calculatesMedianForOddAndEvenWindows() {
        val oddMedian = AdaptivePolling.calculateRobustChangeRate(
            listOf(0.2, 0.9, 0.4, 0.1, 0.3)
        )

        val evenMedian = AdaptivePolling.calculateRobustChangeRate(
            listOf(0.2, 0.9, 0.4, 0.1)
        )

        assertEquals(0.3, oddMedian, absoluteTolerance = 0.0000001)
        assertEquals(0.3, evenMedian, absoluteTolerance = 0.0000001)
    }

    @Test
    fun wakesEarlyForCriticalChangeOrReviewNeed() {
        assertTrue(
            AdaptivePolling.shouldWakeEarly(
                absoluteChange = 0.0,
                relativeChange = 0.6,
                criticalAbsoluteChange = 10.0,
                criticalRelativeChange = 0.5,
                safetyCorridorBreach = false,
                calibrationReviewNeeded = false
            )
        )

        assertTrue(
            AdaptivePolling.shouldWakeEarly(
                absoluteChange = 0.0,
                relativeChange = 0.0,
                criticalAbsoluteChange = 10.0,
                criticalRelativeChange = 0.5,
                safetyCorridorBreach = false,
                calibrationReviewNeeded = true
            )
        )

        assertFalse(
            AdaptivePolling.shouldWakeEarly(
                absoluteChange = 1.0,
                relativeChange = 0.1,
                criticalAbsoluteChange = 10.0,
                criticalRelativeChange = 0.5,
                safetyCorridorBreach = false,
                calibrationReviewNeeded = false
            )
        )
    }

    @Test
    fun calculatesCycleEnergyInJoules() {
        val energy = AdaptivePolling.calculateCycleEnergyJoules(
            voltageVolts = 3.3,
            sleepCurrentAmps = 0.000005,
            sleepDurationSeconds = 59.0,
            wakeCurrentAmps = 0.002,
            wakeDurationSeconds = 0.2,
            sensingCurrentAmps = 0.010,
            sensingDurationSeconds = 0.5,
            computeCurrentAmps = 0.005,
            computeDurationSeconds = 0.2,
            storageCurrentAmps = 0.003,
            storageDurationSeconds = 0.1,
            transmissionCurrentAmps = 0.040,
            transmissionDurationSeconds = 0.5
        )

        assertTrue(energy > 0.0)
    }

    @Test
    fun validatesSleepCurrentAgainstTenMicroampTarget() {
        assertTrue(
            AdaptivePolling.sleepCurrentWithinTarget(
                sleepCurrentAmps = 0.000009
            )
        )

        assertFalse(
            AdaptivePolling.sleepCurrentWithinTarget(
                sleepCurrentAmps = 0.000010
            )
        )
    }
}
