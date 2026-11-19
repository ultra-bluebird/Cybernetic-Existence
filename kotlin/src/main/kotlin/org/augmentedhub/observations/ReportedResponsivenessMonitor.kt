package org.augmentedhub.observations

import kotlin.math.sqrt

data class ResponsivenessEntry(
    val timestampEpochMillis: Long,
    val score: Double,
    val contextReference: String
)

data class ResponsivenessThresholds(
    val minimumRollingStandardDeviation: Double,
    val maximumRollingStandardDeviation: Double,
    val maximumMeanShift: Double,
    val windowSize: Int
)

data class ResponsivenessAssessment(
    val sampleCount: Int,
    val rollingMean: Double?,
    val rollingStandardDeviation: Double?,
    val priorWindowMean: Double?,
    val reviewFlags: Set<ReviewFlag>,
    val explanation: String
) {
    enum class ReviewFlag {
        INSUFFICIENT_DATA,
        LOW_VARIANCE,
        HIGH_VARIANCE,
        MEAN_SHIFT,
        NON_MONOTONIC_TIMESTAMP,
        OUT_OF_RANGE_SCORE
    }
}

object ReportedResponsivenessMonitor {
    fun assess(
        entries: List<ResponsivenessEntry>,
        thresholds: ResponsivenessThresholds
    ): ResponsivenessAssessment {
        validateThresholds(thresholds)

        val flags = mutableSetOf<ResponsivenessAssessment.ReviewFlag>()

        if (entries.any { it.score !in 0.0..10.0 || !it.score.isFinite() }) {
            flags += ResponsivenessAssessment.ReviewFlag.OUT_OF_RANGE_SCORE
        }

        if (entries.zipWithNext().any { (left, right) ->
                right.timestampEpochMillis < left.timestampEpochMillis
            }) {
            flags += ResponsivenessAssessment.ReviewFlag.NON_MONOTONIC_TIMESTAMP
        }

        if (flags.isNotEmpty()) {
            return ResponsivenessAssessment(
                sampleCount = entries.size,
                rollingMean = null,
                rollingStandardDeviation = null,
                priorWindowMean = null,
                reviewFlags = flags,
                explanation = "Input quality must be corrected before trend interpretation."
            )
        }

        if (entries.size < thresholds.windowSize) {
            flags += ResponsivenessAssessment.ReviewFlag.INSUFFICIENT_DATA

            return ResponsivenessAssessment(
                sampleCount = entries.size,
                rollingMean = null,
                rollingStandardDeviation = null,
                priorWindowMean = null,
                reviewFlags = flags,
                explanation = "More host-reported entries are needed for the selected rolling window."
            )
        }

        val currentWindow = entries.takeLast(thresholds.windowSize)
        val currentMean = mean(currentWindow.map { it.score })
        val currentStandardDeviation = standardDeviation(
            currentWindow.map { it.score },
            currentMean
        )

        if (currentStandardDeviation < thresholds.minimumRollingStandardDeviation) {
            flags += ResponsivenessAssessment.ReviewFlag.LOW_VARIANCE
        }

        if (currentStandardDeviation > thresholds.maximumRollingStandardDeviation) {
            flags += ResponsivenessAssessment.ReviewFlag.HIGH_VARIANCE
        }

        val priorWindowMean =
            if (entries.size >= thresholds.windowSize * 2) {
                val priorWindow = entries.dropLast(thresholds.windowSize)
                    .takeLast(thresholds.windowSize)

                mean(priorWindow.map { it.score })
            } else {
                null
            }

        if (
            priorWindowMean != null &&
            kotlin.math.abs(currentMean - priorWindowMean) >
                thresholds.maximumMeanShift
        ) {
            flags += ResponsivenessAssessment.ReviewFlag.MEAN_SHIFT
        }

        return ResponsivenessAssessment(
            sampleCount = entries.size,
            rollingMean = currentMean,
            rollingStandardDeviation = currentStandardDeviation,
            priorWindowMean = priorWindowMean,
            reviewFlags = flags,
            explanation =
                "This is a host-reported trend-review heuristic. A review flag records a change in the log, not proof of cause, degradation, tampering, or internal system state."
        )
    }

    private fun validateThresholds(thresholds: ResponsivenessThresholds) {
        require(
            thresholds.minimumRollingStandardDeviation.isFinite() &&
                thresholds.minimumRollingStandardDeviation >= 0.0
        ) {
            "minimumRollingStandardDeviation must be finite and non-negative."
        }

        require(
            thresholds.maximumRollingStandardDeviation.isFinite() &&
                thresholds.maximumRollingStandardDeviation >
                    thresholds.minimumRollingStandardDeviation
        ) {
            "maximumRollingStandardDeviation must exceed the minimum threshold."
        }

        require(
            thresholds.maximumMeanShift.isFinite() &&
                thresholds.maximumMeanShift >= 0.0
        ) {
            "maximumMeanShift must be finite and non-negative."
        }

        require(thresholds.windowSize >= 3) {
            "windowSize must be at least 3."
        }
    }

    private fun mean(values: List<Double>): Double =
        values.sum() / values.size

    private fun standardDeviation(
        values: List<Double>,
        average: Double
    ): Double =
        sqrt(
            values
                .map { value -> (value - average) * (value - average) }
                .sum() / values.size
        )
}
