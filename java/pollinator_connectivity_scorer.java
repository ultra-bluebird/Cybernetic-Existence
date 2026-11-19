package org.augmentedhub.pollinator;

import java.util.Objects;

public final class PollinatorConnectivityScorer {
    public enum ConfidenceState {
        USABLE,
        REVIEW_REQUIRED,
        INSUFFICIENT_EVIDENCE
    }

    public record Inputs(
            double effectiveResistance,
            double resistanceModelConfidence,
            double habitatObservationCompleteness,
            boolean sensitiveLocationSuppressed
    ) {}

    public record Score(
            double connectionScore,
            double reliabilityAdjustedScore,
            ConfidenceState confidenceState,
            String explanation
    ) {}

    public Score score(Inputs input, double minimumConfidence) {
        Objects.requireNonNull(input, "input");

        if (!Double.isFinite(input.effectiveResistance())
                || input.effectiveResistance() <= 0.0
                || !unitInterval(input.resistanceModelConfidence())
                || !unitInterval(input.habitatObservationCompleteness())
                || !unitInterval(minimumConfidence)) {
            throw new IllegalArgumentException("Connectivity inputs are invalid.");
        }

        final double rawScore = 1.0 / input.effectiveResistance();
        final double evidenceConfidence =
                Math.min(input.resistanceModelConfidence(), input.habitatObservationCompleteness());
        final double adjustedScore = rawScore * evidenceConfidence;

        if (!input.sensitiveLocationSuppressed()) {
            return new Score(
                    rawScore,
                    adjustedScore,
                    ConfidenceState.REVIEW_REQUIRED,
                    "Sensitive-location publication controls have not been confirmed.");
        }

        if (evidenceConfidence < minimumConfidence) {
            return new Score(
                    rawScore,
                    adjustedScore,
                    ConfidenceState.INSUFFICIENT_EVIDENCE,
                    "The resistance model or habitat evidence does not meet the review threshold.");
        }

        return new Score(
                rawScore,
                adjustedScore,
                ConfidenceState.USABLE,
                "Score is suitable for aggregate corridor planning, not as a movement prediction.");
    }

    private static boolean unitInterval(double value) {
        return Double.isFinite(value) && value >= 0.0 && value <= 1.0;
    }
}
