package org.augmentedhub.access;

import java.util.List;
import java.util.Objects;

public final class ConsentBurdenEvaluator {
    private ConsentBurdenEvaluator() {
    }

    public record InterfaceInteractionMetrics(
            String interfaceKey,
            double requiredInteractions,
            double serviceDeliveredUnits,
            double dataRequestedUnits,
            double dataNecessaryUnits,
            boolean alternativeAccessAvailable,
            double burdenThreshold
    ) {
        public InterfaceInteractionMetrics {
            Objects.requireNonNull(interfaceKey, "interfaceKey");

            if (interfaceKey.isBlank()) {
                throw new IllegalArgumentException("interfaceKey must not be blank.");
            }

            requireFiniteNonNegative(
                    requiredInteractions,
                    "requiredInteractions"
            );

            requireFinitePositive(
                    serviceDeliveredUnits,
                    "serviceDeliveredUnits"
            );

            requireFiniteNonNegative(
                    dataRequestedUnits,
                    "dataRequestedUnits"
            );

            requireFinitePositive(
                    dataNecessaryUnits,
                    "dataNecessaryUnits"
            );

            requireFiniteNonNegative(
                    burdenThreshold,
                    "burdenThreshold"
            );
        }
    }

    public record ConsentBurdenResult(
            String interfaceKey,
            double burdenScore,
            boolean redesignRequired,
            String explanationCode
    ) {
    }

    public static ConsentBurdenResult evaluate(
            InterfaceInteractionMetrics metrics
    ) {
        Objects.requireNonNull(metrics, "metrics");

        double alternativeAccess =
                metrics.alternativeAccessAvailable() ? 1.0 : 0.0;

        double burden =
                metrics.requiredInteractions() / metrics.serviceDeliveredUnits()
                        + metrics.dataRequestedUnits() / metrics.dataNecessaryUnits()
                        - alternativeAccess;

        boolean redesignRequired =
                !metrics.alternativeAccessAvailable()
                        || burden > metrics.burdenThreshold();

        String explanationCode;

        if (!metrics.alternativeAccessAvailable()) {
            explanationCode = "LOW_CONSENT_ALTERNATIVE_MISSING";
        } else if (burden > metrics.burdenThreshold()) {
            explanationCode = "CONSENT_BURDEN_THRESHOLD_EXCEEDED";
        } else {
            explanationCode = "CONSENT_BURDEN_WITHIN_THRESHOLD";
        }

        return new ConsentBurdenResult(
                metrics.interfaceKey(),
                burden,
                redesignRequired,
                explanationCode
        );
    }

    public static List<ConsentBurdenResult> interfacesRequiringRedesign(
            List<InterfaceInteractionMetrics> interfaces
    ) {
        Objects.requireNonNull(interfaces, "interfaces");

        return interfaces.stream()
                .map(ConsentBurdenEvaluator::evaluate)
                .filter(ConsentBurdenResult::redesignRequired)
                .toList();
    }

    private static void requireFiniteNonNegative(
            double value,
            String fieldName
    ) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                    fieldName + " must be finite and non-negative."
            );
        }
    }

    private static void requireFinitePositive(
            double value,
            String fieldName
    ) {
        if (!Double.isFinite(value) || value <= 0.0) {
            throw new IllegalArgumentException(
                    fieldName + " must be finite and greater than zero."
            );
        }
    }
}
