package augmentedhub.fog

import kotlin.math.ceil

enum class FogMediaLabel {
    UNMODELED_MEDIA,
    MODELED_MEDIA
}

data class ConformalCalibrationPoint(
    val trueLabel: FogMediaLabel,
    val probabilityForTrueLabel: Double
) {
    init {
        require(probabilityForTrueLabel.isFinite())
        require(probabilityForTrueLabel in 0.0..1.0)
    }

    val nonconformityScore: Double
        get() = 1.0 - probabilityForTrueLabel
}

data class FogConformalPolicy(
    val alpha: Double,
    val minimumCalibrationSize: Int,
    val maximumPredictionSetSize: Int = 2
) {
    init {
        require(alpha > 0.0 && alpha < 1.0)
        require(minimumCalibrationSize >= 2)
        require(maximumPredictionSetSize == FogMediaLabel.entries.size)
    }
}

data class FogConformalResult(
    val predictionSet: Set<FogMediaLabel>,
    val quantile: Double,
    val calibrationSize: Int,
    val alpha: Double,
    val advisoryOnly: Boolean = true,
    val autonomousDecisionAllowed: Boolean = false
) {
    init {
        require(predictionSet.size <= 2)
        require(quantile in 0.0..1.0)
        require(calibrationSize >= 0)
        require(alpha > 0.0 && alpha < 1.0)
        require(advisoryOnly)
        require(!autonomousDecisionAllowed)
    }
}

object FogConformalPrediction {

    fun quantile(
        calibration: List<ConformalCalibrationPoint>,
        policy: FogConformalPolicy
    ): Double {
        require(calibration.size >= policy.minimumCalibrationSize) {
            "Calibration set is below the approved minimum size."
        }

        val sortedScores = calibration
            .map { it.nonconformityScore }
            .sorted()

        val oneBasedIndex = ceil(
            (calibration.size + 1).toDouble() * (1.0 - policy.alpha)
        ).toInt()

        val zeroBasedIndex = oneBasedIndex
            .coerceIn(1, sortedScores.size) - 1

        return sortedScores[zeroBasedIndex]
    }

    fun predict(
        probabilityUnmodeledMedia: Double,
        calibration: List<ConformalCalibrationPoint>,
        policy: FogConformalPolicy
    ): FogConformalResult {
        require(probabilityUnmodeledMedia.isFinite())
        require(probabilityUnmodeledMedia in 0.0..1.0)

        val threshold = quantile(calibration, policy)

        val probabilities = mapOf(
            FogMediaLabel.UNMODELED_MEDIA to probabilityUnmodeledMedia,
            FogMediaLabel.MODELED_MEDIA to 1.0 - probabilityUnmodeledMedia
        )

        val predictionSet = probabilities
            .filter { (_, probability) ->
                1.0 - probability <= threshold
            }
            .keys

        return FogConformalResult(
            predictionSet = predictionSet,
            quantile = threshold,
            calibrationSize = calibration.size,
            alpha = policy.alpha
        )
    }
}
