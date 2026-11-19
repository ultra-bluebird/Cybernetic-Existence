package org.augmentedhub.stoichiometry

import kotlin.math.exp
import kotlin.math.ln

data class SoilMolarPools(
    val carbonMmolPerKg: Double,
    val nitrogenMmolPerKg: Double,
    val phosphorusMmolPerKg: Double
)

data class ReclaimedWaterRegime(
    val irrigationMmPerDay: Double,
    val dissolvedNitrogenMgPerL: Double,
    val dissolvedPhosphorusMgPerL: Double,
    val electricalConductivityDsPerM: Double,
    val sodiumAdsorptionRatio: Double
)

data class StoichiometricReference(
    val meanLogCn: Double,
    val meanLogCp: Double,
    val meanLogNp: Double,
    val inverseCovariance: Array<DoubleArray>
)

data class StoichiometricResult(
    val carbonNitrogenRatio: Double,
    val carbonPhosphorusRatio: Double,
    val nitrogenPhosphorusRatio: Double,
    val mahalanobisDistanceSquared: Double,
    val boundedConditionScore: Double
)

class StoichiometricValidationException(message: String) : IllegalArgumentException(message)

object StoichiometricHexCalibration {
    private const val EPSILON = 1.0e-12

    fun evaluate(
        pools: SoilMolarPools,
        regime: ReclaimedWaterRegime,
        reference: StoichiometricReference
    ): StoichiometricResult {
        validatePools(pools)
        validateRegime(regime)
        validateReference(reference)

        val cn = pools.carbonMmolPerKg / (pools.nitrogenMmolPerKg + EPSILON)
        val cp = pools.carbonMmolPerKg / (pools.phosphorusMmolPerKg + EPSILON)
        val np = pools.nitrogenMmolPerKg / (pools.phosphorusMmolPerKg + EPSILON)

        val centered = doubleArrayOf(
            ln(cn) - reference.meanLogCn,
            ln(cp) - reference.meanLogCp,
            ln(np) - reference.meanLogNp
        )

        var distanceSquared = 0.0
        for (row in 0 until 3) {
            for (column in 0 until 3) {
                distanceSquared += centered[row] *
                    reference.inverseCovariance[row][column] *
                    centered[column]
            }
        }

        if (!distanceSquared.isFinite() || distanceSquared < -EPSILON) {
            throw StoichiometricValidationException(
                "invalid covariance or non-finite reference distance"
            )
        }

        val nonNegativeDistance = distanceSquared.coerceAtLeast(0.0)
        val conditionScore = exp(-0.5 * nonNegativeDistance)

        return StoichiometricResult(
            carbonNitrogenRatio = cn,
            carbonPhosphorusRatio = cp,
            nitrogenPhosphorusRatio = np,
            mahalanobisDistanceSquared = nonNegativeDistance,
            boundedConditionScore = conditionScore.coerceIn(0.0, 1.0)
        )
    }

    private fun validatePools(pools: SoilMolarPools) {
        val values = listOf(
            pools.carbonMmolPerKg,
            pools.nitrogenMmolPerKg,
            pools.phosphorusMmolPerKg
        )

        if (values.any { !it.isFinite() || it < 0.0 }) {
            throw StoichiometricValidationException(
                "soil pools must be finite and non-negative"
            )
        }

        if (pools.nitrogenMmolPerKg <= 0.0 || pools.phosphorusMmolPerKg <= 0.0) {
            throw StoichiometricValidationException(
                "nitrogen and phosphorus pools must be positive"
            )
        }
    }

    private fun validateRegime(regime: ReclaimedWaterRegime) {
        val values = listOf(
            regime.irrigationMmPerDay,
            regime.dissolvedNitrogenMgPerL,
            regime.dissolvedPhosphorusMgPerL,
            regime.electricalConductivityDsPerM,
            regime.sodiumAdsorptionRatio
        )

        if (values.any { !it.isFinite() || it < 0.0 }) {
            throw StoichiometricValidationException(
                "reclaimed-water regime values must be finite and non-negative"
            )
        }
    }

    private fun validateReference(reference: StoichiometricReference) {
        if (reference.inverseCovariance.size != 3 ||
            reference.inverseCovariance.any { it.size != 3 }
        ) {
            throw StoichiometricValidationException(
                "inverse covariance must be a 3 by 3 matrix"
            )
        }

        val meanValues = listOf(
            reference.meanLogCn,
            reference.meanLogCp,
            reference.meanLogNp
        )

        if (meanValues.any { !it.isFinite() }) {
            throw StoichiometricValidationException(
                "reference means must be finite"
            )
        }

        if (reference.inverseCovariance.flatten().any { !it.isFinite() }) {
            throw StoichiometricValidationException(
                "inverse covariance values must be finite"
            )
        }
    }
}
