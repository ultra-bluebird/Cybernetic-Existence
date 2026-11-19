package org.augmentedhub.soil;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class CommunityFunctionProfiler {
    public record WellReading(
            String substrateClass,
            double opticalDensity,
            boolean valid
    ) {
        public WellReading {
            Objects.requireNonNull(substrateClass, "substrateClass");
        }
    }

    public record ProfileResult(
            double averageWellColorDevelopment,
            double shannonFunctionalDiversity,
            int includedWellCount,
            int excludedWellCount,
            boolean interpretable
    ) {}

    public ProfileResult calculate(
            List<WellReading> readings,
            double controlOpticalDensity,
            int minimumIncludedWells) {

        Objects.requireNonNull(readings, "readings");

        if (!Double.isFinite(controlOpticalDensity) || minimumIncludedWells < 1) {
            throw new IllegalArgumentException("Control value and minimum count are invalid.");
        }

        final List<Double> responses = new ArrayList<>();
        int excluded = 0;

        for (WellReading reading : readings) {
            Objects.requireNonNull(reading, "reading");

            if (!reading.valid() || !Double.isFinite(reading.opticalDensity())) {
                excluded++;
                continue;
            }

            responses.add(Math.max(0.0, reading.opticalDensity() - controlOpticalDensity));
        }

        if (responses.size() < minimumIncludedWells) {
            return new ProfileResult(Double.NaN, Double.NaN, responses.size(), excluded, false);
        }

        double responseSum = 0.0;
        for (double response : responses) {
            responseSum += response;
        }

        final double awcd = responseSum / responses.size();
        if (responseSum == 0.0) {
            return new ProfileResult(awcd, 0.0, responses.size(), excluded, true);
        }

        double diversity = 0.0;
        for (double response : responses) {
            if (response == 0.0) {
                continue;
            }

            final double proportion = response / responseSum;
            diversity -= proportion * Math.log(proportion);
        }

        return new ProfileResult(awcd, diversity, responses.size(), excluded, true);
    }
}
