package org.augmentedhub.compute

enum class ComputeDecision {
    PROCEED,
    DERATE,
    HALT,
    INDETERMINATE
}

data class ComputeWorkload(
    val expectedUncertaintyReduction: Double,
    val probabilityPositiveReduction: Double,
    val flops: Double,
    val effectiveFlopsPerJoule: Double,
    val memoryEnergyJoules: Double,
    val networkEnergyJoules: Double,
    val coolingEnergyJoules: Double,
    val carbonIntensityGco2ePerKwh: Double,
    val energyBudgetKwh: Double,
    val waterBudgetLiters: Double,
    val waterUseLiters: Double,
    val heatRisk: Double,
    val maximumHeatRisk: Double,
    val corridorMargin: Double
)

object ComputeUncertaintyGate {
    private const val JOULES_PER_KWH = 3_600_000.0

    fun evaluate(
        workload: ComputeWorkload,
        minimumExpectedReduction: Double,
        minimumProbabilityPositiveReduction: Double,
        maximumCarbonIntensityGco2ePerKwh: Double
    ): ComputeDecision {
        validate(workload, minimumExpectedReduction, minimumProbabilityPositiveReduction,
            maximumCarbonIntensityGco2ePerKwh)

        val computeEnergyJoules =
            workload.flops / workload.effectiveFlopsPerJoule

        val totalEnergyJoules =
            computeEnergyJoules +
                workload.memoryEnergyJoules +
                workload.networkEnergyJoules +
                workload.coolingEnergyJoules

        val totalEnergyKwh = totalEnergyJoules / JOULES_PER_KWH

        val carbonOk =
            workload.carbonIntensityGco2ePerKwh <= maximumCarbonIntensityGco2ePerKwh

        val energyOk = totalEnergyKwh <= workload.energyBudgetKwh
        val waterOk = workload.waterUseLiters <= workload.waterBudgetLiters
        val heatOk = workload.heatRisk <= workload.maximumHeatRisk
        val corridorOk = workload.corridorMargin >= 0.0

        if (!carbonOk || !energyOk || !waterOk || !corridorOk) {
            return ComputeDecision.HALT
        }

        if (!heatOk) {
            return ComputeDecision.DERATE
        }

        if (workload.expectedUncertaintyReduction < minimumExpectedReduction ||
            workload.probabilityPositiveReduction < minimumProbabilityPositiveReduction) {
            return ComputeDecision.INDETERMINATE
        }

        return ComputeDecision.PROCEED
    }

    private fun validate(
        workload: ComputeWorkload,
        minimumExpectedReduction: Double,
        minimumProbabilityPositiveReduction: Double,
        maximumCarbonIntensityGco2ePerKwh: Double
    ) {
        val values = listOf(
            workload.expectedUncertaintyReduction,
            workload.probabilityPositiveReduction,
            workload.flops,
            workload.effectiveFlopsPerJoule,
            workload.memoryEnergyJoules,
            workload.networkEnergyJoules,
            workload.coolingEnergyJoules,
            workload.carbonIntensityGco2ePerKwh,
            workload.energyBudgetKwh,
            workload.waterBudgetLiters,
            workload.waterUseLiters,
            workload.heatRisk,
            workload.maximumHeatRisk,
            workload.corridorMargin,
            minimumExpectedReduction,
            minimumProbabilityPositiveReduction,
            maximumCarbonIntensityGco2ePerKwh
        )

        require(values.all { it.isFinite() }) {
            "all workload and policy values must be finite"
        }

        require(workload.expectedUncertaintyReduction >= 0.0)
        require(workload.probabilityPositiveReduction in 0.0..1.0)
        require(workload.flops >= 0.0)
        require(workload.effectiveFlopsPerJoule > 0.0)
        require(workload.memoryEnergyJoules >= 0.0)
        require(workload.networkEnergyJoules >= 0.0)
        require(workload.coolingEnergyJoules >= 0.0)
        require(workload.carbonIntensityGco2ePerKwh >= 0.0)
        require(workload.energyBudgetKwh >= 0.0)
        require(workload.waterBudgetLiters >= 0.0)
        require(workload.waterUseLiters >= 0.0)
        require(workload.heatRisk in 0.0..1.0)
        require(workload.maximumHeatRisk in 0.0..1.0)
        require(minimumExpectedReduction >= 0.0)
        require(minimumProbabilityPositiveReduction in 0.0..1.0)
        require(maximumCarbonIntensityGco2ePerKwh > 0.0)
    }
}
