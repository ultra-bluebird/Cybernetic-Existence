package org.augmentedhub.gf36;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class Gf36TemporalDecayCalculator {
    public record MetricEvent(Instant occurredAt, double value) {
        public MetricEvent {
            Objects.requireNonNull(occurredAt, "occurredAt");
            if (!Double.isFinite(value)) {
                throw new IllegalArgumentException("value must be finite");
            }
        }
    }

    public record DecayedMetric(
            double weightedMean,
            double totalWeight,
            int eventCount,
            Instant newestEventAt,
            Instant oldestEventAt,
            Duration halfLife,
            boolean lowEvidence
    ) {}

    public DecayedMetric calculate(
            List<MetricEvent> events,
            Instant now,
            Duration halfLife,
            int minimumEventCount,
            double minimumTotalWeight) {

        Objects.requireNonNull(events, "events");
        Objects.requireNonNull(now, "now");
        Objects.requireNonNull(halfLife, "halfLife");

        if (events.isEmpty() || halfLife.isZero() || halfLife.isNegative()
                || minimumEventCount < 1 || minimumTotalWeight <= 0.0) {
            throw new IllegalArgumentException("Invalid decay calculation parameters");
        }

        final double halfLifeSeconds = halfLife.toNanos() / 1_000_000_000.0;
        final double lambda = Math.log(2.0) / halfLifeSeconds;

        double weightedSum = 0.0;
        double totalWeight = 0.0;
        Instant newest = null;
        Instant oldest = null;

        for (MetricEvent event : events) {
            if (event.occurredAt().isAfter(now)) {
                throw new IllegalArgumentException("Future events are not allowed");
            }

            final double ageSeconds = Duration.between(event.occurredAt(), now).toNanos()
                    / 1_000_000_000.0;
            final double weight = Math.exp(-lambda * ageSeconds);

            weightedSum += weight * event.value();
            totalWeight += weight;
            newest = newest == null || event.occurredAt().isAfter(newest)
                    ? event.occurredAt() : newest;
            oldest = oldest == null || event.occurredAt().isBefore(oldest)
                    ? event.occurredAt() : oldest;
        }

        return new DecayedMetric(
                weightedSum / totalWeight,
                totalWeight,
                events.size(),
                newest,
                oldest,
                halfLife,
                events.size() < minimumEventCount || totalWeight < minimumTotalWeight);
    }
}
