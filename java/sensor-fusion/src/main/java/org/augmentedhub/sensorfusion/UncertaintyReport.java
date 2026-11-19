package org.augmentedhub.sensorfusion;

import java.util.Objects;

public final class UncertaintyReport {
    public record Components(
        double stationaryStandardUncertainty,
        double transferStandardUncertainty,
        double mobileRepeatabilityStandardUncertainty,
        double environmentalStandardUncertainty,
        double timeAlignmentStandardUncertainty
    ) {
        public Components {
            requireNonNegativeFinite(
                stationaryStandardUncertainty,
                "stationaryStandardUncertainty"
            );
            requireNonNegativeFinite(
                transferStandardUncertainty,
                "transferStandardUncertainty"
            );
            requireNonNegativeFinite(
                mobileRepeatabilityStandardUncertainty,
                "mobileRepeatabilityStandardUncertainty"
            );
            requireNonNegativeFinite(
                environmentalStandardUncertainty,
                "environmentalStandardUncertainty"
            );
            requireNonNegativeFinite(
                timeAlignmentStandardUncertainty,
                "timeAlignmentStandardUncertainty"
            );
        }
    }

    public record Report(
        String transferId,
        double estimate,
        double combinedStandardUncertainty,
        double expandedUncertainty,
        double coverageFactor,
        String qualityStatus
    ) {
        public Report {
            requireText(transferId, "transferId");
            requireFinite(estimate, "estimate");
            requireNonNegativeFinite(
                combinedStandardUncertainty,
                "combinedStandardUncertainty"
            );
            requireNonNegativeFinite(
                expandedUncertainty,
                "expandedUncertainty"
            );

            if (!Double.isFinite(coverageFactor) || coverageFactor <= 0.0) {
                throw new IllegalArgumentException(
                    "coverageFactor must be finite and greater than zero"
                );
            }

            requireText(qualityStatus, "qualityStatus");
        }
    }

    private UncertaintyReport() {
    }

    public static Report create(
        String transferId,
        double estimate,
        Components components,
        double coverageFactor,
        String qualityStatus
    ) {
        Objects.requireNonNull(components, "components");
        requireText(transferId, "transferId");
        requireFinite(estimate, "estimate");

        if (!Double.isFinite(coverageFactor) || coverageFactor <= 0.0) {
            throw new IllegalArgumentException(
                "coverageFactor must be finite and greater than zero"
            );
        }

        double variance =
            square(components.stationaryStandardUncertainty())
            + square(components.transferStandardUncertainty())
            + square(components.mobileRepeatabilityStandardUncertainty())
            + square(components.environmentalStandardUncertainty())
            + square(components.timeAlignmentStandardUncertainty());

        double combinedStandardUncertainty = Math.sqrt(variance);

        return new Report(
            transferId,
            estimate,
            combinedStandardUncertainty,
            coverageFactor * combinedStandardUncertainty,
            coverageFactor,
            qualityStatus
        );
    }

    private static double square(double value) {
        return value * value;
    }

    private static void requireNonNegativeFinite(double value, String field) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                field + " must be finite and non-negative"
            );
        }
    }

    private static void requireFinite(double value, String field) {
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException(field + " must be finite");
        }
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must be non-empty");
        }
    }
}
