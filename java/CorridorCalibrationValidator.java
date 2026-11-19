package org.augmentedhub.cyboquatic;

import java.util.List;
import java.util.Objects;

public final class CorridorCalibrationValidator {
    public record Segment(
        String anchorId,
        String corridorId,
        double measuredDistanceM,
        double predictedDistanceM,
        double varianceM2,
        double maximumNormalizedResidual
    ) {}

    public record Validation(
        boolean accepted,
        String reason,
        double rAffine,
        int acceptedSegments
    ) {}

    private CorridorCalibrationValidator() {
    }

    public static Validation validate(
        final List<Segment> segments,
        final double corridorThreshold
    ) {
        if (!Double.isFinite(corridorThreshold) || corridorThreshold < 0.0d) {
            return new Validation(
                false,
                "corridor threshold must be finite and non-negative",
                Double.NaN,
                0
            );
        }

        if (segments == null || segments.isEmpty()) {
            return new Validation(
                false,
                "at least one segment is required",
                Double.NaN,
                0
            );
        }

        double sumNormalizedResidual = 0.0d;
        int acceptedSegments = 0;

        for (final Segment segment : segments) {
            if (segment == null) {
                return new Validation(false, "segment must not be null", Double.NaN, acceptedSegments);
            }

            if (!validIdentifier(segment.anchorId()) || !validIdentifier(segment.corridorId())) {
                return new Validation(
                    false,
                    "anchor and corridor identifiers must be non-empty",
                    Double.NaN,
                    acceptedSegments
                );
            }

            if (!finiteNonNegative(segment.measuredDistanceM())
                || !finiteNonNegative(segment.predictedDistanceM())
                || !finitePositive(segment.varianceM2())
                || !finiteNonNegative(segment.maximumNormalizedResidual())) {
                return new Validation(
                    false,
                    "segment values violate distance or variance invariants",
                    Double.NaN,
                    acceptedSegments
                );
            }

            final double residual = segment.measuredDistanceM() - segment.predictedDistanceM();
            final double normalizedResidual = (residual * residual) / segment.varianceM2();

            if (!Double.isFinite(normalizedResidual)) {
                return new Validation(
                    false,
                    "normalized residual is non-finite",
                    Double.NaN,
                    acceptedSegments
                );
            }

            if (normalizedResidual > segment.maximumNormalizedResidual()) {
                return new Validation(
                    false,
                    "segment exceeds its declared normalized-residual limit",
                    normalizedResidual,
                    acceptedSegments
                );
            }

            sumNormalizedResidual += normalizedResidual;
            acceptedSegments++;
        }

        final double rAffine = sumNormalizedResidual / acceptedSegments;

        if (!Double.isFinite(rAffine)) {
            return new Validation(false, "corridor residual is non-finite", Double.NaN, acceptedSegments);
        }

        if (rAffine > corridorThreshold) {
            return new Validation(
                false,
                "corridor residual exceeds the declared threshold",
                rAffine,
                acceptedSegments
            );
        }

        return new Validation(
            true,
            "all segment invariants and corridor residual limits passed",
            rAffine,
            acceptedSegments
        );
    }

    private static boolean validIdentifier(final String value) {
        return value != null && !value.isBlank() && value.length() <= 128;
    }

    private static boolean finiteNonNegative(final double value) {
        return Double.isFinite(value) && value >= 0.0d;
    }

    private static boolean finitePositive(final double value) {
        return Double.isFinite(value) && value > 0.0d;
    }
}
