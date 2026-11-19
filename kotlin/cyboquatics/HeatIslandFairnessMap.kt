package cyboquatics

import kotlin.math.max
import kotlin.math.min

object HeatIslandFairnessMap {
    enum class Decision {
        RESTORATION_PRIORITY_AVAILABLE,
        FAIRNESS_REVIEW_REQUIRED,
        REJECTED_INPUT
    }

    data class AggregateHeatCell(
        val aggregateCellId: String,
        val surfaceTemperatureC: Double,
        val referenceTemperatureC: Double,
        val temperatureRangeC: Double,
        val coverageQuality: Double,
        val communityReviewAvailable: Boolean,
        val enforcementUseProhibited: Boolean,
        val displacementRiskFlag: Boolean,
        val householdOrPersonalDataPresent: Boolean
    )

    data class Result(
        val decision: Decision,
        val heatPriority: Double?,
        val reasons: List<String>
    )

    fun evaluate(cell: AggregateHeatCell): Result {
        val valid = cell.aggregateCellId.isNotBlank() &&
            cell.surfaceTemperatureC.isFinite() &&
            cell.referenceTemperatureC.isFinite() &&
            cell.temperatureRangeC.isFinite() &&
            cell.temperatureRangeC > 0.0 &&
            cell.coverageQuality.isFinite() &&
            cell.coverageQuality in 0.0..1.0

        if (!valid) {
            return Result(
                Decision.REJECTED_INPUT,
                null,
                listOf("Aggregate thermal inputs must be complete, finite, and within configured bounds.")
            )
        }

        val reasons = mutableListOf<String>()
        if (!cell.communityReviewAvailable) reasons += "Accessible community review is unavailable."
        if (!cell.enforcementUseProhibited) reasons += "The no-enforcement-use restriction is missing."
        if (cell.displacementRiskFlag) reasons += "A community displacement-risk review is active."
        if (cell.householdOrPersonalDataPresent) reasons += "Household or personal data is prohibited."

        val rawHeat = (cell.surfaceTemperatureC - cell.referenceTemperatureC) / cell.temperatureRangeC
        val heatPriority = clamp01(rawHeat) * cell.coverageQuality

        return if (reasons.isEmpty()) {
            Result(
                Decision.RESTORATION_PRIORITY_AVAILABLE,
                heatPriority,
                listOf("Use only for community-led restoration planning, never enforcement or individual targeting.")
            )
        } else {
            Result(Decision.FAIRNESS_REVIEW_REQUIRED, heatPriority, reasons)
        }
    }

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
