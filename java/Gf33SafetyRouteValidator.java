package org.augmentedhub.gf33;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class Gf33SafetyRouteValidator {
    public enum Status {
        ACCEPTED,
        REJECTED_INVALID_INPUT,
        REJECTED_UNVALIDATED_PROFILE,
        REJECTED_SPEED,
        REJECTED_SEPARATION,
        REJECTED_STOP_TIME,
        REJECTED_PROTECTION_STATE
    }

    public record ZoneProfile(
            String zoneId,
            boolean validatedForOperation,
            boolean personnelProtectionRequired,
            double maximumSpeedMps,
            double minimumSeparationM,
            double validatedDecelerationMps2,
            double totalResponseLatencyS,
            double uncertaintyMarginM,
            double criticalObstacleDistanceM,
            double maximumStopTimeS
    ) {
        public ZoneProfile {
            Objects.requireNonNull(zoneId, "zoneId");
        }
    }

    public record Observation(
            Instant observedAt,
            String zoneId,
            double speedMps,
            double nearestPersonDistanceM,
            double nearestObstacleDistanceM,
            boolean personnelProtectionActive
    ) {
        public Observation {
            Objects.requireNonNull(observedAt, "observedAt");
            Objects.requireNonNull(zoneId, "zoneId");
        }
    }

    public record Result(
            Status status,
            String reason,
            double requiredStoppingDistanceM,
            double conservativeStopTimeS
    ) {
        public boolean accepted() {
            return status == Status.ACCEPTED;
        }
    }

    public Result validate(Observation observation, ZoneProfile profile) {
        Objects.requireNonNull(observation, "observation");
        Objects.requireNonNull(profile, "profile");

        if (!observation.zoneId().equals(profile.zoneId())
                || !profile.validatedForOperation()
                || !valid(profile.maximumSpeedMps())
                || !positive(profile.validatedDecelerationMps2())
                || !valid(profile.totalResponseLatencyS())
                || !valid(profile.uncertaintyMarginM())) {
            return new Result(
                    Status.REJECTED_UNVALIDATED_PROFILE,
                    "The observation does not match a validated, internally consistent zone profile.",
                    Double.NaN,
                    Double.NaN);
        }

        if (!valid(observation.speedMps())
                || !valid(observation.nearestPersonDistanceM())
                || !valid(observation.nearestObstacleDistanceM())) {
            return new Result(
                    Status.REJECTED_INVALID_INPUT,
                    "Distance and speed measurements must be finite and non-negative.",
                    Double.NaN,
                    Double.NaN);
        }

        if (profile.personnelProtectionRequired() && !observation.personnelProtectionActive()) {
            return new Result(
                    Status.REJECTED_PROTECTION_STATE,
                    "Required personnel protection is not active.",
                    Double.NaN,
                    Double.NaN);
        }

        final double requiredDistance = stoppingDistance(observation.speedMps(), profile);
        final double stopTime = conservativeStopTime(observation.speedMps(), profile);

        if (observation.speedMps() > profile.maximumSpeedMps()) {
            return new Result(
                    Status.REJECTED_SPEED,
                    "Commanded speed exceeds the validated zone maximum.",
                    requiredDistance,
                    stopTime);
        }

        if (observation.nearestPersonDistanceM()
                < Math.max(profile.minimumSeparationM(), requiredDistance)
                || observation.nearestObstacleDistanceM() < requiredDistance) {
            return new Result(
                    Status.REJECTED_SEPARATION,
                    "Available separation is less than the required conservative stopping envelope.",
                    requiredDistance,
                    stopTime);
        }

        if (observation.nearestObstacleDistanceM() < profile.criticalObstacleDistanceM()
                && stopTime > profile.maximumStopTimeS()) {
            return new Result(
                    Status.REJECTED_STOP_TIME,
                    "Emergency-stop timing exceeds the validated deadline.",
                    requiredDistance,
                    stopTime);
        }

        return new Result(
                Status.ACCEPTED,
                "Observation fits the configured validated safety envelope.",
                requiredDistance,
                stopTime);
    }

    public boolean isFresh(Observation observation, Instant now, Duration maximumAge) {
        Objects.requireNonNull(observation, "observation");
        Objects.requireNonNull(now, "now");
        Objects.requireNonNull(maximumAge, "maximumAge");
        return !observation.observedAt().isAfter(now)
                && Duration.between(observation.observedAt(), now).compareTo(maximumAge) <= 0;
    }

    private static double stoppingDistance(double speedMps, ZoneProfile profile) {
        return speedMps * profile.totalResponseLatencyS()
                + (speedMps * speedMps) / (2.0 * profile.validatedDecelerationMps2())
                + profile.uncertaintyMarginM();
    }

    private static double conservativeStopTime(double speedMps, ZoneProfile profile) {
        return profile.totalResponseLatencyS() + speedMps / profile.validatedDecelerationMps2();
    }

    private static boolean valid(double value) {
        return Double.isFinite(value) && value >= 0.0;
    }

    private static boolean positive(double value) {
        return Double.isFinite(value) && value > 0.0;
    }
}
