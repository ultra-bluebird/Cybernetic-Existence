package org.augmentedhub.thermal;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

public final class ThermalBenefitCalculator {
    private ThermalBenefitCalculator() {
    }

    public record WbgtMeasurement(
            Instant observedAt,
            double observedWbgtC
    ) {
        public WbgtMeasurement {
            Objects.requireNonNull(observedAt, "observedAt");

            if (!Double.isFinite(observedWbgtC)
                    || observedWbgtC < -10.0
                    || observedWbgtC > 70.0) {
                throw new IllegalArgumentException(
                        "observedWbgtC must be finite and within -10.0..70.0."
                );
            }
        }
    }

    public record ThermalBenefitResult(
            double totalPersonDegreeHours,
            int measurementCount,
            Duration coveredDuration
    ) {
    }

    /**
     * Integrates thermal benefit using left-interval rectangular integration.
     *
     * Each measurement contributes:
     * max(0, comfortThresholdWbgtC - observedWbgtC)
     * multiplied by population and by the duration until the next sample.
     *
     * The final sample has no subsequent interval and therefore contributes
     * no additional duration. Callers should include a closing sample at the
     * desired end time.
     */
    public static ThermalBenefitResult calculatePersonDegreeHours(
            List<WbgtMeasurement> measurements,
            double comfortThresholdWbgtC,
            long population
    ) {
        Objects.requireNonNull(measurements, "measurements");

        if (measurements.size() < 2) {
            throw new IllegalArgumentException(
                    "At least two WBGT measurements are required for integration."
            );
        }

        if (!Double.isFinite(comfortThresholdWbgtC)
                || comfortThresholdWbgtC < 10.0
                || comfortThresholdWbgtC > 45.0) {
            throw new IllegalArgumentException(
                    "comfortThresholdWbgtC must be finite and within 10.0..45.0."
            );
        }

        if (population <= 0L) {
            throw new IllegalArgumentException(
                    "population must be greater than zero."
            );
        }

        List<WbgtMeasurement> ordered = measurements.stream()
                .sorted(Comparator.comparing(WbgtMeasurement::observedAt))
                .toList();

        double total = 0.0;
        Duration coveredDuration = Duration.ZERO;

        for (int index = 0; index < ordered.size() - 1; index++) {
            WbgtMeasurement current = ordered.get(index);
            WbgtMeasurement next = ordered.get(index + 1);

            Duration interval = Duration.between(
                    current.observedAt(),
                    next.observedAt()
            );

            if (interval.isZero() || interval.isNegative()) {
                throw new IllegalArgumentException(
                        "WBGT measurements must have strictly increasing timestamps."
                );
            }

            double intervalHours = interval.toMillis() / 3_600_000.0;
            double temperatureRelief = Math.max(
                    0.0,
                    comfortThresholdWbgtC - current.observedWbgtC()
            );

            total += temperatureRelief * population * intervalHours;
            coveredDuration = coveredDuration.plus(interval);
        }

        return new ThermalBenefitResult(
                total,
                ordered.size(),
                coveredDuration
        );
    }
}
