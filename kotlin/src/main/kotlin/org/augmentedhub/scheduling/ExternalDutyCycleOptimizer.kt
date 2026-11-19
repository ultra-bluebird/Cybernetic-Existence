package org.augmentedhub.scheduling

import kotlin.math.max
import kotlin.math.min

data class ExternalDutyCycleInputs(
    val maximumDutyCycle: Double,
    val minimumDutyCycle: Double,
    val stepSize: Double,
    val expectedExternalBenefitAtFullDuty: Double,
    val expectedExternalEnergyCostAtFullDuty: Double,
    val expectedHeatLoadAtFullDuty: Double,
    val selfReportedWorkloadBurdenAtFullDuty: Double,
    val uvIndex: Double,
    val maximumUvIndex: Double,
    val environmentalHeatScore: Double,
    val maximumEnvironmentalHeatScore: Double,
    val externalDeviceAuthorized: Boolean
)

data class DutyCycleWeights(
    val energyCost: Double,
    val heatCost: Double,
    val workloadBurden: Double
)

data class DutyCycleDecision(
    val recommendedDutyCycle: Double?,
    val objectiveValue: Double?,
    val status: Status,
    val explanation: String
) {
    enum class Status {
        RECOMMENDED,
        DEFERRED_UV_CONSTRAINT,
        DEFERRED_HEAT_CONSTRAINT,
        DENIED_UNAUTHORIZED_DEVICE,
        INVALID_INPUT
    }
}

object ExternalDutyCycleOptimizer {
    fun optimize(
        inputs: ExternalDutyCycleInputs,
        weights: DutyCycleWeights
    ): DutyCycleDecision {
        val validationError = validate(inputs, weights)

        if (validationError != null) {
            return DutyCycleDecision(
                recommendedDutyCycle = null,
                objectiveValue = null,
                status = DutyCycleDecision.Status.INVALID_INPUT,
                explanation = validationError
            )
        }

        if (!inputs.externalDeviceAuthorized) {
            return DutyCycleDecision(
                recommendedDutyCycle = null,
                objectiveValue = null,
                status = DutyCycleDecision.Status.DENIED_UNAUTHORIZED_DEVICE,
                explanation = "The external device is not authorized for workload scheduling."
            )
        }

        if (inputs.uvIndex > inputs.maximumUvIndex) {
            return DutyCycleDecision(
                recommendedDutyCycle = null,
                objectiveValue = null,
                status = DutyCycleDecision.Status.DEFERRED_UV_CONSTRAINT,
                explanation = "The scheduling window exceeds the configured UV planning limit."
            )
        }

        if (inputs.environmentalHeatScore > inputs.maximumEnvironmentalHeatScore) {
            return DutyCycleDecision(
                recommendedDutyCycle = null,
                objectiveValue = null,
                status = DutyCycleDecision.Status.DEFERRED_HEAT_CONSTRAINT,
                explanation = "The scheduling window exceeds the configured environmental heat limit."
            )
        }

        var bestDutyCycle = inputs.minimumDutyCycle
        var bestObjective = Double.NEGATIVE_INFINITY
        var dutyCycle = inputs.minimumDutyCycle

        while (dutyCycle <= inputs.maximumDutyCycle + 1e-9) {
            val benefit =
                dutyCycle * inputs.expectedExternalBenefitAtFullDuty

            val energyCost =
                dutyCycle * inputs.expectedExternalEnergyCostAtFullDuty

            val heatCost =
                dutyCycle * inputs.expectedHeatLoadAtFullDuty

            val workloadBurden =
                dutyCycle * inputs.selfReportedWorkloadBurdenAtFullDuty

            val objective = benefit -
                (weights.energyCost * energyCost) -
                (weights.heatCost * heatCost) -
                (weights.workloadBurden * workloadBurden)

            if (objective > bestObjective) {
                bestObjective = objective
                bestDutyCycle = dutyCycle
            }

            dutyCycle += inputs.stepSize
        }

        return DutyCycleDecision(
            recommendedDutyCycle = min(max(bestDutyCycle, 0.0), 1.0),
            objectiveValue = bestObjective,
            status = DutyCycleDecision.Status.RECOMMENDED,
            explanation = "Recommendation applies only to an authorized external workload and does not infer biological energy transfer, internal-device state, or nanoswarm activity."
        )
    }

    private fun validate(
        inputs: ExternalDutyCycleInputs,
        weights: DutyCycleWeights
    ): String? {
        val unitIntervalValues = listOf(
            inputs.minimumDutyCycle,
            inputs.maximumDutyCycle,
            inputs.environmentalHeatScore,
            inputs.maximumEnvironmentalHeatScore
        )

        if (unitIntervalValues.any { !it.isFinite() || it < 0.0 || it > 1.0 }) {
            return "Duty-cycle and normalized heat values must be finite and within [0, 1]."
        }

        if (
            !inputs.stepSize.isFinite() ||
            inputs.stepSize <= 0.0 ||
            inputs.stepSize > 1.0
        ) {
            return "stepSize must be finite and within (0, 1]."
        }

        if (inputs.minimumDutyCycle > inputs.maximumDutyCycle) {
            return "minimumDutyCycle must not exceed maximumDutyCycle."
        }

        if (
            !inputs.uvIndex.isFinite() ||
            !inputs.maximumUvIndex.isFinite() ||
            inputs.uvIndex < 0.0 ||
            inputs.maximumUvIndex < 0.0
        ) {
            return "UV inputs must be finite and non-negative."
        }

        val nonNegativeInputs = listOf(
            inputs.expectedExternalBenefitAtFullDuty,
            inputs.expectedExternalEnergyCostAtFullDuty,
            inputs.expectedHeatLoadAtFullDuty,
            inputs.selfReportedWorkloadBurdenAtFullDuty,
            weights.energyCost,
            weights.heatCost,
            weights.workloadBurden
        )

        if (nonNegativeInputs.any { !it.isFinite() || it < 0.0 }) {
            return "Benefits, costs, and weights must be finite and non-negative."
        }

        return null
    }
}
