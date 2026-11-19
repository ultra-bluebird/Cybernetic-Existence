package org.augmentedhub.environment;

import java.util.Objects;

public final class EnvironmentalShieldingFactor {
    public record Input(
        double incidentIrradianceWattsPerM2,
        double shadeTransmission,
        double structureTransmission,
        double clothingTransmission,
        double eyewearTransmission,
        double reflectiveEnvironmentMultiplier
    ) {
        public Input {
            validateNonNegative(
                incidentIrradianceWattsPerM2,
                "incidentIrradianceWattsPerM2"
            );
            validateUnitInterval(shadeTransmission, "shadeTransmission");
            validateUnitInterval(
                structureTransmission,
                "structureTransmission"
            );
            validateUnitInterval(
                clothingTransmission,
                "clothingTransmission"
            );
            validateUnitInterval(
                eyewearTransmission,
                "eyewearTransmission"
            );

            if (
                !Double.isFinite(reflectiveEnvironmentMultiplier) ||
                reflectiveEnvironmentMultiplier < 1.0
            ) {
                throw new IllegalArgumentException(
                    "reflectiveEnvironmentMultiplier must be finite and at least 1.0"
                );
            }
        }
    }

    public record Result(
        double effectiveIrradianceWattsPerM2,
        double shieldingFactor,
        Classification classification,
        String boundary
    ) {}

    public enum Classification {
        HIGHER_SHIELDING,
        MODERATE_SHIELDING,
        LOWER_SHIELDING,
        NO_INCIDENT_IRRADIANCE
    }

    private EnvironmentalShieldingFactor() {}

    public static Result calculate(Input input) {
        Objects.requireNonNull(input, "input must not be null");

        if (input.incidentIrradianceWattsPerM2() == 0.0) {
            return new Result(
                0.0,
                1.0,
                Classification.NO_INCIDENT_IRRADIANCE,
                "Environmental planning metric only; not a physiological or internal-system measurement."
            );
        }

        double transmissionProduct =
            input.shadeTransmission()
                * input.structureTransmission()
                * input.clothingTransmission()
                * input.eyewearTransmission()
                * input.reflectiveEnvironmentMultiplier();

        double effectiveIrradiance =
            input.incidentIrradianceWattsPerM2() * transmissionProduct;

        double shieldingFactor = clamp(
            1.0 - (
                effectiveIrradiance
                    / input.incidentIrradianceWattsPerM2()
            ),
            0.0,
            1.0
        );

        Classification classification =
            shieldingFactor >= 0.75
                ? Classification.HIGHER_SHIELDING
                : shieldingFactor >= 0.40
                    ? Classification.MODERATE_SHIELDING
                    : Classification.LOWER_SHIELDING;

        return new Result(
            effectiveIrradiance,
            shieldingFactor,
            classification,
            "Environmental planning metric only; not a physiological or internal-system measurement."
        );
    }

    private static void validateUnitInterval(
        double value,
        String fieldName
    ) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                fieldName + " must be finite and within [0, 1]"
            );
        }
    }

    private static void validateNonNegative(
        double value,
        String fieldName
    ) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                fieldName + " must be finite and non-negative"
            );
        }
    }

    private static double clamp(
        double value,
        double minimum,
        double maximum
    ) {
        return Math.min(Math.max(value, minimum), maximum);
    }
}
