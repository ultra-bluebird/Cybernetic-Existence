package org.augmentedhub.environment;

import java.time.Instant;
import java.util.Objects;

public final class ShadeSensorFusion {
    public enum ShadeClassification {
        SAFE_SHADE,
        PARTIAL_SHADE,
        OPEN_SUN,
        INDOOR_OR_COVERED,
        INSUFFICIENT_DATA
    }

    public record SensorInput(
        Instant observedAt,
        double visibleLightLux,
        double visibleLightReferenceLux,
        double uvIndex,
        double solarGeometryFactor,
        double coverContextScore,
        double dataQuality
    ) {
        public SensorInput {
            Objects.requireNonNull(observedAt, "observedAt must not be null");

            validateNonNegative(visibleLightLux, "visibleLightLux");
            validatePositive(
                visibleLightReferenceLux,
                "visibleLightReferenceLux"
            );
            validateNonNegative(uvIndex, "uvIndex");
            validateUnitInterval(
                solarGeometryFactor,
                "solarGeometryFactor"
            );
            validateUnitInterval(
                coverContextScore,
                "coverContextScore"
            );
            validateUnitInterval(dataQuality, "dataQuality");
        }
    }

    public record ShadeAssessment(
        ShadeClassification classification,
        double normalizedVisibleLight,
        double normalizedUvExposure,
        double estimatedExposure,
        double shadeScore,
        double dataQuality,
        String boundary
    ) {}

    private static final double MINIMUM_DATA_QUALITY = 0.50;
    private static final double UNCERTAINTY_PENALTY = 0.25;

    private ShadeSensorFusion() {}

    public static ShadeAssessment classify(SensorInput input) {
        Objects.requireNonNull(input, "input must not be null");

        double normalizedVisibleLight = clamp(
            input.visibleLightLux() / input.visibleLightReferenceLux(),
            0.0,
            1.0
        );

        double normalizedUvExposure = clamp(
            input.uvIndex() / 11.0,
            0.0,
            1.0
        );

        double solarAdjustedUv =
            normalizedUvExposure *
            input.solarGeometryFactor();

        double primaryExposure = Math.max(
            normalizedVisibleLight,
            solarAdjustedUv
        );

        double estimatedExposure = clamp(
            (
                primaryExposure *
                    (1.0 - input.coverContextScore())
            ) +
                (
                    (1.0 - input.dataQuality()) *
                    UNCERTAINTY_PENALTY
                ),
            0.0,
            1.0
        );

        ShadeClassification classification;

        if (input.dataQuality() < MINIMUM_DATA_QUALITY) {
            classification = ShadeClassification.INSUFFICIENT_DATA;
        } else if (input.coverContextScore() >= 0.85) {
            classification = ShadeClassification.INDOOR_OR_COVERED;
        } else if (estimatedExposure <= 0.25) {
            classification = ShadeClassification.SAFE_SHADE;
        } else if (estimatedExposure <= 0.60) {
            classification = ShadeClassification.PARTIAL_SHADE;
        } else {
            classification = ShadeClassification.OPEN_SUN;
        }

        return new ShadeAssessment(
            classification,
            normalizedVisibleLight,
            normalizedUvExposure,
            estimatedExposure,
            1.0 - estimatedExposure,
            input.dataQuality(),
            "Environmental sensing result only; it is not a health, identity, or internal-system assessment."
        );
    }

    private static void validateUnitInterval(
        double value,
        String fieldName
    ) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                fieldName + " must be finite and within [0, 1]."
            );
        }
    }

    private static void validateNonNegative(
        double value,
        String fieldName
    ) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                fieldName + " must be finite and non-negative."
            );
        }
    }

    private static void validatePositive(
        double value,
        String fieldName
    ) {
        if (!Double.isFinite(value) || value <= 0.0) {
            throw new IllegalArgumentException(
                fieldName + " must be finite and greater than zero."
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
