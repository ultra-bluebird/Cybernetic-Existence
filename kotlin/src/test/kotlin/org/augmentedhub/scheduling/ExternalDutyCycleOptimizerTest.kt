package org.augmentedhub.scheduling

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

class ExternalDutyCycleOptimizerTest {
    @Test
    fun recommendsAnExternalDutyCycleWithinConfiguredBounds() {
        val result = ExternalDutyCycleOptimizer.optimize(
            inputs = ExternalDutyCycleInputs(
                maximumDutyCycle = 1.0,
                minimumDutyCycle = 0.0,
                stepSize = 0.1,
                expectedExternalBenefitAtFullDuty = 10.0,
                expectedExternalEnergyCostAtFullDuty = 2.0,
                expectedHeatLoadAtFullDuty = 1.0,
                selfReportedWorkloadBurdenAtFullDuty = 1.0,
                uvIndex = 2.0,
                maximumUvIndex = 3.0,
                environmentalHeatScore = 0.2,
                maximumEnvironmentalHeatScore = 0.5,
                externalDeviceAuthorized = true
            ),
            weights = DutyCycleWeights(
                energyCost = 1.0,
                heatCost = 1.0,
                workloadBurden = 1.0
            )
        )

        assertEquals(
            DutyCycleDecision.Status.RECOMMENDED,
            result.status
        )

        assertNotNull(result.recommendedDutyCycle)
        assert(result.recommendedDutyCycle in 0.0..1.0)
    }

    @Test
    fun defersWhenConfiguredUvLimitIsExceeded() {
        val result = ExternalDutyCycleOptimizer.optimize(
            inputs = ExternalDutyCycleInputs(
                maximumDutyCycle = 1.0,
                minimumDutyCycle = 0.0,
                stepSize = 0.1,
                expectedExternalBenefitAtFullDuty = 10.0,
                expectedExternalEnergyCostAtFullDuty = 2.0,
                expectedHeatLoadAtFullDuty = 1.0,
                selfReportedWorkloadBurdenAtFullDuty = 1.0,
                uvIndex = 8.0,
                maximumUvIndex = 3.0,
                environmentalHeatScore = 0.2,
                maximumEnvironmentalHeatScore = 0.5,
                externalDeviceAuthorized = true
            ),
            weights = DutyCycleWeights(
                energyCost = 1.0,
                heatCost = 1.0,
                workloadBurden = 1.0
            )
        )

        assertEquals(
            DutyCycleDecision.Status.DEFERRED_UV_CONSTRAINT,
            result.status
        )
    }
}
