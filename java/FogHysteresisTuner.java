package augmentedhub.fog;

import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

public final class FogHysteresisTuner {

    public record HistoricalObservation(
            double uncertainty,
            boolean referenceUnmodeled
    ) {
        public HistoricalObservation {
            if (!Double.isFinite(uncertainty)
                    || uncertainty < 0.0
                    || uncertainty > 1.0) {
                throw new IllegalArgumentException(
                        "uncertainty must be finite and in [0, 1]"
                );
            }
        }
    }

    public record CandidatePolicy(
            double thetaLow,
            double thetaHigh,
            long minimumDwellSeconds
    ) {
        public CandidatePolicy {
            if (!Double.isFinite(thetaLow)
                    || !Double.isFinite(thetaHigh)
                    || thetaLow < 0.0
                    || thetaHigh > 1.0
                    || thetaLow >= thetaHigh) {
                throw new IllegalArgumentException(
                        "require 0 <= thetaLow < thetaHigh <= 1"
                );
            }
            if (minimumDwellSeconds <= 0) {
                throw new IllegalArgumentException(
                        "minimumDwellSeconds must be positive"
                );
            }
        }
    }

    public record Evaluation(
            CandidatePolicy policy,
            double falsePositiveCost,
            double falseNegativeCost,
            double toggleCost,
            double totalCost,
            long falsePositiveCount,
            long falseNegativeCount,
            long transitionCount
    ) {}

    private FogHysteresisTuner() {}

    public static Evaluation evaluate(
            List<HistoricalObservation> observations,
            CandidatePolicy policy,
            double falsePositiveUnitCost,
            double falseNegativeUnitCost,
            double transitionUnitCost
    ) {
        Objects.requireNonNull(observations, "observations");
        Objects.requireNonNull(policy, "policy");

        validateNonNegative(falsePositiveUnitCost, "falsePositiveUnitCost");
        validateNonNegative(falseNegativeUnitCost, "falseNegativeUnitCost");
        validateNonNegative(transitionUnitCost, "transitionUnitCost");

        boolean stateUnmodeled = false;
        long falsePositives = 0L;
        long falseNegatives = 0L;
        long transitions = 0L;

        for (HistoricalObservation observation : observations) {
            boolean nextState = stateUnmodeled;

            if (observation.uncertainty() > policy.thetaHigh()) {
                nextState = true;
            } else if (observation.uncertainty() < policy.thetaLow()) {
                nextState = false;
            }

            if (nextState != stateUnmodeled) {
                transitions++;
            }

            stateUnmodeled = nextState;

            if (stateUnmodeled && !observation.referenceUnmodeled()) {
                falsePositives++;
            } else if (!stateUnmodeled && observation.referenceUnmodeled()) {
                falseNegatives++;
            }
        }

        double falsePositiveCost = falsePositives * falsePositiveUnitCost;
        double falseNegativeCost = falseNegatives * falseNegativeUnitCost;
        double toggleCost = transitions * transitionUnitCost;

        return new Evaluation(
                policy,
                falsePositiveCost,
                falseNegativeCost,
                toggleCost,
                falsePositiveCost + falseNegativeCost + toggleCost,
                falsePositives,
                falseNegatives,
                transitions
        );
    }

    public static Optional<Evaluation> choosePolicy(
            List<Evaluation> evaluations,
            long maximumAllowedFalseNegatives
    ) {
        if (maximumAllowedFalseNegatives < 0L) {
            throw new IllegalArgumentException(
                    "maximumAllowedFalseNegatives must be non-negative"
            );
        }

        return evaluations.stream()
                .filter(item -> item.falseNegativeCount()
                        <= maximumAllowedFalseNegatives)
                .min(Comparator.comparingDouble(Evaluation::totalCost));
    }

    private static void validateNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                    name + " must be finite and non-negative"
            );
        }
    }
}
