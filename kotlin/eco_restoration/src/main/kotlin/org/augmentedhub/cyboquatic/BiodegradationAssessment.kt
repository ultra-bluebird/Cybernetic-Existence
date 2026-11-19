package org.augmentedhub.cyboquatic

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class BiodegradationSample(
    val method: String,
    val blankMgL: Double,
    val inoculumMgL: Double,
    val referenceMgL: Double,
    val testMgL: Double,
    val referencePassDay: Double,
    val testPassDay: Double,
    val temperatureC: Double,
    val ph: Double
)

data class BiodegradationAssessment(
    val accepted: Boolean,
    val reason: String,
    val correctedTestPct: Double,
    val correctedReferencePct: Double,
    val readiness: Double
)

object BiodegradationAssessmentEngine {
    private val thresholds = mapOf(
        "ISO14851" to 60.0,
        "ISO14855" to 60.0,
        "OECD301" to 60.0,
        "OECD201" to 50.0,
        "OECD202" to 50.0
    )

    fun assess(sample: BiodegradationSample): BiodegradationAssessment {
        val threshold = thresholds[sample.method]
            ?: return BiodegradationAssessment(false, "unsupported_method", 0.0, 0.0, 0.0)

        val valid =
            inRange(sample.blankMgL, 0.0, 100000.0) &&
            inRange(sample.inoculumMgL, 0.0, 100000.0) &&
            inRange(sample.referenceMgL, 0.0, 100000.0) &&
            inRange(sample.testMgL, 0.0, 100000.0) &&
            inRange(sample.referencePassDay, 0.0, 60.0) &&
            inRange(sample.testPassDay, 0.0, 60.0) &&
            inRange(sample.temperatureC, 0.0, 45.0) &&
            inRange(sample.ph, 4.0, 10.0)

        if (!valid) {
            return BiodegradationAssessment(false, "invalid_measurement_range", 0.0, 0.0, 0.0)
        }

        val denominator = max(sample.referenceMgL - sample.blankMgL, 0.001)
        val correctedReference = clamp(
            100.0 * (sample.referenceMgL - sample.blankMgL) / denominator, 0.0, 100.0)
        val correctedTest = clamp(
            100.0 * (sample.testMgL - sample.blankMgL) / denominator, 0.0, 100.0)

        val biodegradationFactor = clamp(correctedTest / threshold, 0.0, 1.0)
        val referenceFactor = if (correctedReference >= 95.0) 1.0 else correctedReference / 95.0
        val temperatureFactor = clamp(1.0 - abs(sample.temperatureC - 20.0) / 20.0, 0.0, 1.0)
        val phFactor = clamp(1.0 - abs(sample.ph - 7.0) / 3.0, 0.0, 1.0)
        val timingFactor = clamp(1.0 - sample.testPassDay / 60.0, 0.0, 1.0)

        val readiness = clamp(
            0.50 * biodegradationFactor +
                0.20 * referenceFactor +
                0.15 * temperatureFactor +
                0.10 * phFactor +
                0.05 * timingFactor,
            0.0,
            1.0
        )

        val accepted =
            correctedTest >= threshold &&
                correctedReference >= 95.0 &&
                sample.testPassDay <= 28.0

        return BiodegradationAssessment(
            accepted,
            if (accepted) "advisory_candidate" else "insufficient_evidence",
            correctedTest,
            correctedReference,
            readiness
        )
    }

    private fun inRange(value: Double, low: Double, high: Double): Boolean =
        value.isFinite() && value in low..high

    private fun clamp(value: Double, low: Double, high: Double): Double =
        max(low, min(high, value))
}
