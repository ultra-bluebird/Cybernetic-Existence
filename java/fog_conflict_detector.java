package org.augmentedhub.fog;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class FogConflictDetector {
    public enum Decision {
        FOG_SUPPORTED,
        CLEAR_SUPPORTED,
        UNKNOWN,
        CONFLICT_REVIEW_REQUIRED,
        STALE_EVIDENCE,
        INVALID_EVIDENCE
    }

    public record Evidence(
            String sourceClass,
            Instant observedAt,
            double clearMass,
            double fogMass,
            double ignoranceMass
    ) {
        public Evidence {
            Objects.requireNonNull(sourceClass, "sourceClass");
            Objects.requireNonNull(observedAt, "observedAt");
        }

        public boolean isValid() {
            return finiteNonNegative(clearMass)
                    && finiteNonNegative(fogMass)
                    && finiteNonNegative(ignoranceMass)
                    && Math.abs(clearMass + fogMass + ignoranceMass - 1.0) <= 1e-9;
        }
    }

    public record Assessment(
            Decision decision,
            double fogBelief,
            double fogPlausibility,
            double conflict,
            String reason
    ) {}

    private final double conflictThreshold;
    private final double supportThreshold;

    public FogConflictDetector(double conflictThreshold, double supportThreshold) {
        if (!validThreshold(conflictThreshold) || !validThreshold(supportThreshold)) {
            throw new IllegalArgumentException("Thresholds must be finite values in [0, 1).");
        }
        this.conflictThreshold = conflictThreshold;
        this.supportThreshold = supportThreshold;
    }

    public Assessment assess(
            List<Evidence> observations,
            Instant now,
            Duration maximumEvidenceAge) {

        Objects.requireNonNull(observations, "observations");
        Objects.requireNonNull(now, "now");
        Objects.requireNonNull(maximumEvidenceAge, "maximumEvidenceAge");

        if (observations.isEmpty()) {
            return new Assessment(
                    Decision.INVALID_EVIDENCE, Double.NaN, Double.NaN, Double.NaN,
                    "At least one evidence record is required.");
        }

        Evidence accumulated = observations.getFirst();
        if (!accumulated.isValid()) {
            return invalid();
        }

        double maximumConflict = 0.0;

        for (Evidence observation : observations) {
            if (!observation.isValid()) {
                return invalid();
            }

            if (observation.observedAt().isAfter(now)
                    || Duration.between(observation.observedAt(), now)
                    .compareTo(maximumEvidenceAge) > 0) {
                return new Assessment(
                        Decision.STALE_EVIDENCE, 0.0, 1.0, maximumConflict,
                        "Evidence is stale or timestamped in the future.");
            }
        }

        for (int index = 1; index < observations.size(); index++) {
            Evidence next = observations.get(index);

            double conflict = accumulated.clearMass() * next.fogMass()
                    + accumulated.fogMass() * next.clearMass();

            maximumConflict = Math.max(maximumConflict, conflict);

            if (conflict >= 1.0 - 1e-12 || conflict > conflictThreshold) {
                return new Assessment(
                        Decision.CONFLICT_REVIEW_REQUIRED,
                        0.0,
                        1.0,
                        maximumConflict,
                        "Sensor disagreement exceeds the approved threshold.");
            }

            double denominator = 1.0 - conflict;
            accumulated = new Evidence(
                    "combined",
                    later(accumulated.observedAt(), next.observedAt()),
                    (
                        accumulated.clearMass() * next.clearMass()
                        + accumulated.clearMass() * next.ignoranceMass()
                        + accumulated.ignoranceMass() * next.clearMass()
                    ) / denominator,
                    (
                        accumulated.fogMass() * next.fogMass()
                        + accumulated.fogMass() * next.ignoranceMass()
                        + accumulated.ignoranceMass() * next.fogMass()
                    ) / denominator,
                    (accumulated.ignoranceMass() * next.ignoranceMass()) / denominator
            );
        }

        double fogBelief = accumulated.fogMass();
        double fogPlausibility = accumulated.fogMass() + accumulated.ignoranceMass();
        double clearBelief = accumulated.clearMass();

        if (fogBelief >= supportThreshold) {
            return new Assessment(
                    Decision.FOG_SUPPORTED,
                    fogBelief,
                    fogPlausibility,
                    maximumConflict,
                    "Combined evidence supports fog.");
        }

        if (clearBelief >= supportThreshold) {
            return new Assessment(
                    Decision.CLEAR_SUPPORTED,
                    fogBelief,
                    fogPlausibility,
                    maximumConflict,
                    "Combined evidence supports clear conditions.");
        }

        return new Assessment(
                Decision.UNKNOWN,
                fogBelief,
                fogPlausibility,
                maximumConflict,
                "Evidence remains materially uncertain.");
    }

    private static Assessment invalid() {
        return new Assessment(
                Decision.INVALID_EVIDENCE, Double.NaN, Double.NaN, Double.NaN,
                "Mass values must be finite, non-negative, and sum to one.");
    }

    private static Instant later(Instant first, Instant second) {
        return first.isAfter(second) ? first : second;
    }

    private static boolean finiteNonNegative(double value) {
        return Double.isFinite(value) && value >= 0.0;
    }

    private static boolean validThreshold(double value) {
        return Double.isFinite(value) && value >= 0.0 && value < 1.0;
    }
}
