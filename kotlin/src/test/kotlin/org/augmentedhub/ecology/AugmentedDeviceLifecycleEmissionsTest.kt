package org.augmentedhub.ecology

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AugmentedDeviceLifecycleEmissionsTest {
    @Test
    fun longerLastingRepairableDeviceHasLowerAnnualizedLifecycleEmissions() {
        val durableScenario = AugmentedDeviceLifecycleInput(
            deviceClass = "repairable-exoskeleton",
            deviceCount = 100,
            manufacturingCarbonGramsPerDevice = 900_000.0,
            transportCarbonGramsPerDevice = 20_000.0,
            endOfLifeCarbonGramsPerDevice = 30_000.0,
            expectedServiceLifeYears = 10.0,
            scenarioAssessmentPeriodYears = 20.0,
            repairLifeExtensionYears = 5.0,
            recoveredMaterialCreditGramsPerDevice = 100_000.0,
        )

        val shortLivedScenario = AugmentedDeviceLifecycleInput(
            deviceClass = "short-lived-exoskeleton",
            deviceCount = 100,
            manufacturingCarbonGramsPerDevice = 500_000.0,
            transportCarbonGramsPerDevice = 15_000.0,
            endOfLifeCarbonGramsPerDevice = 25_000.0,
            expectedServiceLifeYears = 3.0,
            scenarioAssessmentPeriodYears = 20.0,
            repairLifeExtensionYears = 0.0,
            recoveredMaterialCreditGramsPerDevice = 20_000.0,
        )

        val durableAssessment = assessAugmentedDeviceLifecycle(durableScenario)
        val shortLivedAssessment = assessAugmentedDeviceLifecycle(shortLivedScenario)

        assertTrue(
            durableAssessment.annualizedLifecycleCarbonGrams
                < shortLivedAssessment.annualizedLifecycleCarbonGrams,
        )

        assertTrue(
            compareLifecycleScenarios(
                durableScenario,
                shortLivedScenario,
            ) > 0.0,
        )
    }

    @Test
    fun result_metrics_include_lifecycle_and_operational_emissions() {
        val lifecycle = assessAugmentedDeviceLifecycle(
            AugmentedDeviceLifecycleInput(
                deviceClass = "neural-interface",
                deviceCount = 50,
                manufacturingCarbonGramsPerDevice = 200_000.0,
                transportCarbonGramsPerDevice = 10_000.0,
                endOfLifeCarbonGramsPerDevice = 15_000.0,
                expectedServiceLifeYears = 8.0,
                scenarioAssessmentPeriodYears = 8.0,
                repairLifeExtensionYears = 2.0,
                recoveredMaterialCreditGramsPerDevice = 40_000.0,
            ),
        )

        val metrics = calculateResultMetrics(
            operationalInput = OperationalEmissionsInput(
                gridElectricityKilowattHours = 10_000.0,
                gridCarbonGramsPerKilowattHour = 300.0,
                operationalTransportCarbonGrams = 50_000.0,
                facilityCarbonGrams = 10_000.0,
            ),
            lifecycleAssessments = listOf(lifecycle),
            carbonReferenceGrams = 10_000_000.0,
        )

        assertTrue(metrics.augmentedDeviceLifecycleCarbonGrams > 0.0)
        assertTrue(metrics.totalCityCarbonFootprintGrams > metrics.operationalCarbonGrams)
        assertTrue(metrics.ecoImpactValue in 0.0..1.0)
        assertEquals(0.94, metrics.accessibilityImpact)
    }
}
