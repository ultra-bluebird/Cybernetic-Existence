package org.augmentedhub.aquatic;

import java.util.List;
import java.util.Objects;

public final class AquaticBioticIndexCalculator {
    public record TaxonAggregate(
            String reportingGroup,
            int count,
            double toleranceValue,
            boolean includedInIndex
    ) {
        public TaxonAggregate {
            Objects.requireNonNull(reportingGroup, "reportingGroup");

            if (count < 0 || !Double.isFinite(toleranceValue)
                    || toleranceValue < 0.0 || toleranceValue > 10.0) {
                throw new IllegalArgumentException(
                        "Count and tolerance value are outside allowed bounds.");
            }
        }
    }

    public record Result(
            double hilsenhoffBioticIndex,
            int includedOrganismCount,
            int includedGroupCount,
            boolean minimumCountReached,
            String interpretationNote
    ) {}

    public Result calculate(List<TaxonAggregate> groups, int minimumOrganismCount) {
        Objects.requireNonNull(groups, "groups");

        if (groups.isEmpty() || minimumOrganismCount < 1) {
            throw new IllegalArgumentException("Groups and minimum count are required.");
        }

        long totalCount = 0L;
        double weightedToleranceSum = 0.0;
        int includedGroups = 0;

        for (TaxonAggregate group : groups) {
            Objects.requireNonNull(group, "group");

            if (!group.includedInIndex()) {
                continue;
            }

            totalCount += group.count();
            weightedToleranceSum += group.count() * group.toleranceValue();

            if (group.count() > 0) {
                includedGroups++;
            }
        }

        if (totalCount == 0L) {
            throw new IllegalArgumentException(
                    "No included aquatic invertebrate observations are available.");
        }

        final double hbi = weightedToleranceSum / totalCount;
        final boolean adequate = totalCount >= minimumOrganismCount;

        return new Result(
                hbi,
                Math.toIntExact(totalCount),
                includedGroups,
                adequate,
                adequate
                        ? "Interpret with locally approved tolerance values and complementary water data."
                        : "Result is retained for quality review and should not be published as conclusive.");
    }
}
