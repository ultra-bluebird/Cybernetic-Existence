package org.augmentedhub.ecology

import kotlin.math.max
import kotlin.math.min

data class OperationalEmissionsInput(
    val gridElectricityKilowattHours: Double,
    val gridCarbonGramsPerKilowattHour: Double,
    val operationalTransportCarbonGrams: Double,
    val facilityCarbonGrams: Double,
)

data class AugmentedDeviceLifecycleInput(
    val deviceClass: String,
    val deviceCount: Int,
    val manufacturingCarbonGramsPerDevice: Double,
    val transportCarbonGramsPerDevice: Double,
    val endOfLifeCarbonGramsPerDevice: Double,
    val expectedServiceLifeYears: Double,
    val scenarioAssessmentPeriodYears: Double,
    val repairLifeExtensionYears: Double,
    val recoveredMaterialCreditGramsPerDevice: Double,
)

data class LifecycleEmissionsAssessment(
    val deviceClass: String,
    val annualizedManufacturingCarbonGrams: Double,
    val annualizedTransportCarbonGrams: Double,
    val annualizedEndOfLifeCarbonGrams: Double,
    val annualizedRecoveredMaterialCreditGrams: Double,
    val annualizedLifecycleCarbonGrams: Double,
    val effectiveServiceLifeYears: Double,
)

data class ResultMetrics(
    val operationalCarbonGrams: Double,
    val augmentedDeviceLifecycleCarbonGrams: Double,
    val totalCityCarbonFootprintGrams: Double,
    val ecoImpactValue: Double,
    val knowledgeFactor: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double,
    val explanation: String,
)

class LifecycleEmissionsError(message: String) : IllegalArgumentException(message)

fun assessAugmentedDeviceLifecycle(
    input: AugmentedDeviceLifecycleInput,
): LifecycleEmissionsAssessment {
    require(input.deviceClass.isNotBlank()) {
        "deviceClass must not be blank"
    }

    require(input.deviceCount >= 0) {
        "deviceCount must be non-negative"
    }

    requireFiniteNonNegative(
        "manufacturingCarbonGramsPerDevice",
        input.manufacturingCarbonGramsPerDevice,
    )
    requireFiniteNonNegative(
        "transportCarbonGramsPerDevice",
        input.transportCarbonGramsPerDevice,
    )
    requireFiniteNonNegative(
        "endOfLifeCarbonGramsPerDevice",
        input.endOfLifeCarbonGramsPerDevice,
    )
    requireFinitePositive(
        "expectedServiceLifeYears",
        input.expectedServiceLifeYears,
    )
    requireFinitePositive(
        "scenarioAssessmentPeriodYears",
        input.scenarioAssessmentPeriodYears,
    )
    requireFiniteNonNegative(
        "repairLifeExtensionYears",
        input.repairLifeExtensionYears,
    )
    requireFiniteNonNegative(
        "recoveredMaterialCreditGramsPerDevice",
        input.recoveredMaterialCreditGrams,
    )

    val effectiveServiceLifeYears = (
        input.expectedServiceLifeYears + input.repairLifeExtensionYears
    )

    require(effectiveServiceLifeYears > 0.0) {
        "effectiveServiceLifeYears must be positive"
    }

    val replacementCycles = (
        input.scenarioAssessmentPeriodYears / effectiveServiceLifeYears
    )

    val manufacturingCarbonGrams = (
        input.deviceCount
        * input.manufacturingCarbonGramsPerDevice
        * replacementCycles
    )

    val transportCarbonGrams = (
        input.deviceCount
        * input.transportCarbonGramsPerDevice
        * replacementCycles
    )

    val endOfLifeCarbonGrams = (
        input.deviceCount
        * input.endOfLifeCarbonGramsPerDevice
        * replacementCycles
    )

    val recoveredMaterialCreditGrams = (
        input.deviceCount
        * input.recoveredMaterialCreditGramsPerDevice
        * replacementCycles
    )

    val annualizationDivisor = input.scenarioAssessmentPeriodYears

    return LifecycleEmissionsAssessment(
        deviceClass = input.deviceClass,
        annualizedManufacturingCarbonGrams =
            manufacturingCarbonGrams / annualizationDivisor,
        annualizedTransportCarbonGrams =
            transportCarbonGrams / annualizationDivisor,
        annualizedEndOfLifeCarbonGrams =
            endOfLifeCarbonGrams / annualizationDivisor,
        annualizedRecoveredMaterialCreditGrams =
            recoveredMaterialCreditGrams / annualizationDivisor,
        annualizedLifecycleCarbonGrams = (
            manufacturingCarbonGrams
            + transportCarbonGrams
            + endOfLifeCarbonGrams
            - recoveredMaterialCreditGrams
        ) / annualizationDivisor,
        effectiveServiceLifeYears = effectiveServiceLifeYears,
    )
}

fun calculateResultMetrics(
    operationalInput: OperationalEmissionsInput,
    lifecycleAssessments: List<LifecycleEmissionsAssessment>,
    carbonReferenceGrams: Double,
): ResultMetrics {
    requireFiniteNonNegative(
        "gridElectricityKilowattHours",
        operationalInput.gridElectricityKilowattHours,
    )
    requireFiniteNonNegative(
        "gridCarbonGramsPerKilowattHour",
        operationalInput.gridCarbonGramsPerKilowattHour,
    )
    requireFiniteNonNegative(
        "operationalTransportCarbonGrams",
        operationalInput.operationalTransportCarbonGrams,
    )
    requireFiniteNonNegative(
        "facilityCarbonGrams",
        operationalInput.facilityCarbonGrams,
    )
    requireFinitePositive("carbonReferenceGrams", carbonReferenceGrams)

    val operationalCarbonGrams = (
        operationalInput.gridElectricityKilowattHours
        * operationalInput.gridCarbonGramsPerKilowattHour
        + operationalInput.operationalTransportCarbonGrams
        + operationalInput.facilityCarbonGrams
    )

    val augmentedDeviceLifecycleCarbonGrams = lifecycleAssessments.sumOf {
        it.annualizedLifecycleCarbonGrams
    }

    val totalCityCarbonFootprintGrams = (
        operationalCarbonGrams + augmentedDeviceLifecycleCarbonGrams
    )

    val ecoImpactValue = clampUnitInterval(
        1.0 - totalCityCarbonFootprintGrams / carbonReferenceGrams,
    )

    return ResultMetrics(
        operationalCarbonGrams = operationalCarbonGrams,
        augmentedDeviceLifecycleCarbonGrams =
            augmentedDeviceLifecycleCarbonGrams,
        totalCityCarbonFootprintGrams = totalCityCarbonFootprintGrams,
        ecoImpactValue = ecoImpactValue,
        knowledgeFactor = 0.90,
        harmRisk = 0.16,
        accessibilityImpact = 0.94,
        rightsAlignment = 0.95,
        explanation =
            "The city carbon footprint combines operational emissions with annualized lifecycle emissions from augmented-device classes. Lifecycle accounting includes manufacturing, transport, end-of-life processing, recovery credit, expected service life, and repair-enabled life extension.",
    )
}

fun compareLifecycleScenarios(
    durableScenario: AugmentedDeviceLifecycleInput,
    shortLivedScenario: AugmentedDeviceLifecycleInput,
): Double {
    val durable = assessAugmentedDeviceLifecycle(durableScenario)
    val shortLived = assessAugmentedDeviceLifecycle(shortLivedScenario)

    return shortLived.annualizedLifecycleCarbonGrams -
        durable.annualizedLifecycleCarbonGrams
}

private fun requireFinitePositive(name: String, value: Double) {
    if (!value.isFinite() || value <= 0.0) {
        throw LifecycleEmissionsError("$name must be finite and positive")
    }
}

private fun requireFiniteNonNegative(name: String, value: Double) {
    if (!value.isFinite() || value < 0.0) {
        throw LifecycleEmissionsError("$name must be finite and non-negative")
    }
}

private fun clampUnitInterval(value: Double): Double {
    return min(1.0, max(0.0, value))
}
