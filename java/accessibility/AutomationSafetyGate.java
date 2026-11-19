package org.augmentedhub.accessibility;

import java.util.Objects;

public final class AutomationSafetyGate {
    public enum Decision {
        ALLOW_ADVISORY,
        NEEDS_REVIEW,
        BLOCKED
    }

    public record Assessment(
            double knowledgeFactor,
            double ecoImpactValue,
            double harmRisk,
            double accessibilityImpact,
            double rightsAlignment,
            boolean humanReviewAvailable,
            boolean accessibleNoticeAvailable,
            boolean explicitConsentRequired,
            boolean explicitConsentPresent,
            boolean physicalActuationRequested,
            String explanation
    ) {
        public Assessment {
            requireUnitInterval(knowledgeFactor, "knowledgeFactor");
            requireUnitInterval(ecoImpactValue, "ecoImpactValue");
            requireUnitInterval(harmRisk, "harmRisk");
            requireUnitInterval(accessibilityImpact, "accessibilityImpact");
            requireUnitInterval(rightsAlignment, "rightsAlignment");
            Objects.requireNonNull(explanation, "explanation");
        }
    }

    private AutomationSafetyGate() {
    }

    public static Decision evaluate(Assessment assessment) {
        Objects.requireNonNull(assessment, "assessment");

        if (assessment.physicalActuationRequested()) {
            return Decision.BLOCKED;
        }

        if (assessment.harmRisk() > 0.45) {
            return Decision.BLOCKED;
        }

        if (!assessment.humanReviewAvailable()) {
            return Decision.NEEDS_REVIEW;
        }

        if (!assessment.accessibleNoticeAvailable()) {
            return Decision.NEEDS_REVIEW;
        }

        if (assessment.explicitConsentRequired() &&
                !assessment.explicitConsentPresent()) {
            return Decision.BLOCKED;
        }

        if (assessment.knowledgeFactor() < 0.60 ||
                assessment.accessibilityImpact() < 0.70 ||
                assessment.rightsAlignment() < 0.80) {
            return Decision.NEEDS_REVIEW;
        }

        if (assessment.ecoImpactValue() < 0.50) {
            return Decision.NEEDS_REVIEW;
        }

        return Decision.ALLOW_ADVISORY;
    }

    private static void requireUnitInterval(double value, String label) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(label + " must be finite and within [0, 1]");
        }
    }
}
