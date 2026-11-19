package org.augmentedhub.privacy;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.SplittableRandom;

public final class PrivacyAggregationService {
    public enum ReleaseDecision {
        RELEASED,
        SUPPRESSED_INSUFFICIENT_COHORT,
        SUPPRESSED_BUDGET_EXHAUSTED,
        SUPPRESSED_INVALID_REQUEST,
        REVIEW_REQUIRED
    }

    public record AggregateRequest(
            String metricReference,
            String purposeReference,
            List<Double> boundedContributions,
            double lowerBound,
            double upperBound,
            int minimumCohortSize,
            double epsilon,
            double availableBudget
    ) {
        public AggregateRequest {
            Objects.requireNonNull(metricReference, "metricReference");
            Objects.requireNonNull(purposeReference, "purposeReference");
            Objects.requireNonNull(boundedContributions, "boundedContributions");

            if (metricReference.isBlank()
                    || purposeReference.isBlank()
                    || boundedContributions.isEmpty()
                    || !Double.isFinite(lowerBound)
                    || !Double.isFinite(upperBound)
                    || lowerBound >= upperBound
                    || minimumCohortSize < 1
                    || !Double.isFinite(epsilon)
                    || epsilon <= 0.0
                    || !Double.isFinite(availableBudget)
                    || availableBudget < 0.0) {
                throw new IllegalArgumentException("Invalid privacy aggregation request.");
            }
        }
    }

    public record Release(
            ReleaseDecision decision,
            Double trueMean,
            Double releasedMean,
            int contributionCount,
            double epsilonConsumed,
            String explanation
    ) {}

    private final SplittableRandom random;

    public PrivacyAggregationService(SplittableRandom random) {
        this.random = Objects.requireNonNull(random, "random");
    }

    public Release releaseBoundedMean(AggregateRequest request, Instant now) {
        Objects.requireNonNull(request, "request");
        Objects.requireNonNull(now, "now");

        if (request.boundedContributions().size() < request.minimumCohortSize()) {
            return new Release(
                    ReleaseDecision.SUPPRESSED_INSUFFICIENT_COHORT,
                    null,
                    null,
                    request.boundedContributions().size(),
                    0.0,
                    "The cohort is below the minimum release threshold.");
        }

        if (request.epsilon() > request.availableBudget()) {
            return new Release(
                    ReleaseDecision.SUPPRESSED_BUDGET_EXHAUSTED,
                    null,
                    null,
                    request.boundedContributions().size(),
                    0.0,
                    "The approved privacy budget is insufficient for this release.");
        }

        double sum = 0.0;

        for (Double contribution : request.boundedContributions()) {
            if (contribution == null
                    || !Double.isFinite(contribution)
                    || contribution < request.lowerBound()
                    || contribution > request.upperBound()) {
                return new Release(
                        ReleaseDecision.SUPPRESSED_INVALID_REQUEST,
                        null,
                        null,
                        request.boundedContributions().size(),
                        0.0,
                        "A restricted contribution is missing, non-finite, or outside the approved bounds.");
            }

            sum += contribution;
        }

        double trueMean = sum / request.boundedContributions().size();
        double meanSensitivity =
                (request.upperBound() - request.lowerBound())
                        / request.boundedContributions().size();

        double noise = sampleLaplace(meanSensitivity / request.epsilon());
        double releasedMean = clamp(
                trueMean + noise,
                request.lowerBound(),
                request.upperBound());

        return new Release(
                ReleaseDecision.RELEASED,
                trueMean,
                releasedMean,
                request.boundedContributions().size(),
                request.epsilon(),
                "A differentially private aggregate is ready for governed public release.");
    }

    private double sampleLaplace(double scale) {
        if (!Double.isFinite(scale) || scale <= 0.0) {
            throw new IllegalArgumentException("Laplace scale must be finite and positive.");
        }

        double uniform = random.nextDouble(-0.5, 0.5);
        return -scale * Math.signum(uniform)
                * Math.log(1.0 - 2.0 * Math.abs(uniform));
    }

    private static double clamp(double value, double lower, double upper) {
        return Math.max(lower, Math.min(upper, value));
    }
}
