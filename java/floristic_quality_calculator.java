package org.augmentedhub.floristic;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public final class FloristicQualityCalculator {
    public record NativePlantAggregate(
            String protectedTaxonReference,
            double coefficientOfConservatism,
            boolean nativeToReferenceRegion,
            boolean includedAfterQualityReview
    ) {
        public NativePlantAggregate {
            Objects.requireNonNull(protectedTaxonReference, "protectedTaxonReference");

            if (!Double.isFinite(coefficientOfConservatism)
                    || coefficientOfConservatism < 0.0
                    || coefficientOfConservatism > 10.0) {
                throw new IllegalArgumentException(
                        "Coefficient of conservatism must be in the interval [0, 10].");
            }
        }
    }

    public record Result(
            int nativeSpeciesRichness,
            double meanCoefficientOfConservatism,
            double floristicQualityIndex,
            boolean sufficientForInterpretation,
            String note
    ) {}

    public Result calculate(
            List<NativePlantAggregate> observations,
            int minimumNativeSpeciesCount) {

        Objects.requireNonNull(observations, "observations");

        if (observations.isEmpty() || minimumNativeSpeciesCount < 1) {
            throw new IllegalArgumentException(
                    "Observations and a positive minimum species count are required.");
        }

        final Set<String> distinctNativeTaxa = new HashSet<>();
        double coefficientSum = 0.0;

        for (NativePlantAggregate observation : observations) {
            Objects.requireNonNull(observation, "observation");

            if (!observation.nativeToReferenceRegion()
                    || !observation.includedAfterQualityReview()) {
                continue;
            }

            if (distinctNativeTaxa.add(observation.protectedTaxonReference())) {
                coefficientSum += observation.coefficientOfConservatism();
            }
        }

        final int nativeRichness = distinctNativeTaxa.size();

        if (nativeRichness == 0) {
            return new Result(
                    0,
                    Double.NaN,
                    Double.NaN,
                    false,
                    "No reviewed native taxa are available for calculation.");
        }

        final double meanCoefficient = coefficientSum / nativeRichness;
        final double fqi = meanCoefficient * Math.sqrt(nativeRichness);
        final boolean sufficient = nativeRichness >= minimumNativeSpeciesCount;

        return new Result(
                nativeRichness,
                meanCoefficient,
                fqi,
                sufficient,
                sufficient
                        ? "Result is an aggregate floristic indicator tied to its regional reference revision."
                        : "Result requires quality review because native richness is below the approved minimum.");
    }
}
