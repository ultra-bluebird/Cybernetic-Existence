package org.augmentedhub.environment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

final class EnvironmentalShieldingFactorTest {
    @Test
    void multipleExternalBarriersIncreaseShielding() {
        var result = EnvironmentalShieldingFactor.calculate(
            new EnvironmentalShieldingFactor.Input(
                800.0,
                0.35,
                0.70,
                0.30,
                0.20,
                1.05
            )
        );

        assertTrue(result.shieldingFactor() > 0.75);
        assertEquals(
            EnvironmentalShieldingFactor.Classification.HIGHER_SHIELDING,
            result.classification()
        );
    }

    @Test
    void zeroIncidentIrradianceReturnsNoExposureState() {
        var result = EnvironmentalShieldingFactor.calculate(
            new EnvironmentalShieldingFactor.Input(
                0.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0
            )
        );

        assertEquals(0.0, result.effectiveIrradianceWattsPerM2());
        assertEquals(1.0, result.shieldingFactor());
        assertEquals(
            EnvironmentalShieldingFactor.Classification.NO_INCIDENT_IRRADIANCE,
            result.classification()
        );
    }
}
