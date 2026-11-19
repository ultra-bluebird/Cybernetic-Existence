package org.augmentedhub.gf37;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

public final class Gf37KaplanMeier {
    public record Observation(
            int elapsedStage,
            boolean abandonmentObserved
    ) {
        public Observation {
            if (elapsedStage < 0) {
                throw new IllegalArgumentException("elapsedStage must be non-negative");
            }
        }
    }

    public record Point(
            int stage,
            int atRisk,
            int abandonments,
            int censored,
            double survival,
            double discreteHazard
    ) {}

    public List<Point> estimate(List<Observation> observations, int minimumCohortSize) {
        Objects.requireNonNull(observations, "observations");
        if (minimumCohortSize < 1) {
            throw new IllegalArgumentException("minimumCohortSize must be positive");
        }
        if (observations.size() < minimumCohortSize) {
            return List.of();
        }

        final List<Observation> sorted = new ArrayList<>(observations);
        sorted.sort(Comparator.comparingInt(Observation::elapsedStage));

        final List<Point> points = new ArrayList<>();
        double survival = 1.0;
        int atRisk = sorted.size();
        int index = 0;

        while (index < sorted.size()) {
            final int stage = sorted.get(index).elapsedStage();
            int abandonments = 0;
            int censored = 0;

            while (index < sorted.size() && sorted.get(index).elapsedStage() == stage) {
                if (sorted.get(index).abandonmentObserved()) {
                    abandonments++;
                } else {
                    censored++;
                }
                index++;
            }

            if (atRisk > 0) {
                final double conditionalSurvival = 1.0 - ((double) abandonments / atRisk);
                survival *= conditionalSurvival;

                points.add(new Point(
                        stage,
                        atRisk,
                        abandonments,
                        censored,
                        survival,
                        (double) abandonments / atRisk));
            }

            atRisk -= abandonments + censored;
        }

        return List.copyOf(points);
    }
}
