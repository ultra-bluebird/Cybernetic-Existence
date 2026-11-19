package org.augmentedhub.cyboquatic

import java.math.BigDecimal
import java.math.RoundingMode

data class WetlandCellDesign(
    val cellId: String,
    val vegetationCoverFraction: BigDecimal,
    val openWaterFraction: BigDecimal,
    val emergentVegetationFraction: BigDecimal,
    val hydraulicLoadingMPerDay: BigDecimal,
    val hydraulicRetentionTimeDays: BigDecimal,
    val waterDepthM: BigDecimal
) {
    init {
        require(cellId.matches(Regex("[a-z0-9][a-z0-9_-]{7,127}"))) {
            "cellId must use the local stable identifier grammar"
        }
        require(vegetationCoverFraction in BigDecimal.ZERO..BigDecimal.ONE) {
            "vegetationCoverFraction must be in [0, 1]"
        }
        require(openWaterFraction in BigDecimal.ZERO..BigDecimal.ONE) {
            "openWaterFraction must be in [0, 1]"
        }
        require(emergentVegetationFraction in BigDecimal.ZERO..BigDecimal.ONE) {
            "emergentVegetationFraction must be in [0, 1]"
        }
        require(openWaterFraction + emergentVegetationFraction <= BigDecimal.ONE) {
            "open-water and emergent-vegetation fractions must not exceed one"
        }
        require(hydraulicLoadingMPerDay >= BigDecimal.ZERO) {
            "hydraulicLoadingMPerDay must be non-negative"
        }
        require(hydraulicRetentionTimeDays > BigDecimal.ZERO) {
            "hydraulicRetentionTimeDays must be positive"
        }
        require(waterDepthM >= BigDecimal.ZERO) {
            "waterDepthM must be non-negative"
        }
    }

    fun openWaterToEmergentRatio(): BigDecimal? =
        if (emergentVegetationFraction == BigDecimal.ZERO) {
            null
        } else {
            openWaterFraction.divide(
                emergentVegetationFraction,
                12,
                RoundingMode.HALF_EVEN
            )
        }
}

data class DesignEnvelope(
    val maximumHydraulicLoadingMPerDay: BigDecimal,
    val minimumRetentionTimeDays: BigDecimal,
    val minimumVegetationCoverage: BigDecimal,
    val maximumOpenWaterFraction: BigDecimal
) {
    init {
        require(maximumHydraulicLoadingMPerDay >= BigDecimal.ZERO)
        require(minimumRetentionTimeDays > BigDecimal.ZERO)
        require(minimumVegetationCoverage in BigDecimal.ZERO..BigDecimal.ONE)
        require(maximumOpenWaterFraction in BigDecimal.ZERO..BigDecimal.ONE)
    }
}

sealed interface DesignComparison {
    data class WithinEnvelope(
        val ratio: BigDecimal?
    ) : DesignComparison

    data class RequiresFieldReview(
        val reasons: List<String>
    ) : DesignComparison
}

object ConstructedWetlandDesignComparator {
    fun compare(
        design: WetlandCellDesign,
        envelope: DesignEnvelope
    ): DesignComparison {
        val reasons = buildList {
            if (design.hydraulicLoadingMPerDay > envelope.maximumHydraulicLoadingMPerDay) {
                add("hydraulic loading exceeds the selected design envelope")
            }

            if (design.hydraulicRetentionTimeDays < envelope.minimumRetentionTimeDays) {
                add("hydraulic retention time is below the selected design envelope")
            }

            if (design.vegetationCoverFraction < envelope.minimumVegetationCoverage) {
                add("vegetation coverage is below the selected design envelope")
            }

            if (design.openWaterFraction > envelope.maximumOpenWaterFraction) {
                add("open-water fraction exceeds the selected design envelope")
            }
        }

        return if (reasons.isEmpty()) {
            DesignComparison.WithinEnvelope(design.openWaterToEmergentRatio())
        } else {
            DesignComparison.RequiresFieldReview(reasons)
        }
    }

    fun pfASRemovalClaimAllowed(): Boolean = false
}
