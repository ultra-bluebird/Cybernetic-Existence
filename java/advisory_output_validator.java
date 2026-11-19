package org.augmentedhub.advisory;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;

public final class AdvisoryOutputValidator {
    public enum Classification {
        ADVISORY
    }

    public record OutputRecord(
            String outputDigest,
            Instant createdAt,
            Classification classification,
            String producerModule,
            String evidenceDigest,
            String accessibleExplanation
    ) {
        public OutputRecord {
            Objects.requireNonNull(outputDigest, "outputDigest");
            Objects.requireNonNull(createdAt, "createdAt");
            Objects.requireNonNull(classification, "classification");
            Objects.requireNonNull(producerModule, "producerModule");
            Objects.requireNonNull(evidenceDigest, "evidenceDigest");
            Objects.requireNonNull(accessibleExplanation, "accessibleExplanation");
        }
    }

    private static final Set<String> PROHIBITED_OPERATIONAL_TERMS = Set.of(
            "actuate",
            "command",
            "control",
            "deploy",
            "dispatch",
            "enable",
            "disable",
            "open-valve",
            "close-valve",
            "start-motor",
            "stop-motor"
    );

    public boolean isValidFogAdvisory(OutputRecord output) {
        Objects.requireNonNull(output, "output");

        if (output.classification() != Classification.ADVISORY
                || output.outputDigest().isBlank()
                || output.evidenceDigest().isBlank()
                || output.accessibleExplanation().isBlank()
                || !output.producerModule().startsWith("fog-advisory-")) {
            return false;
        }

        final String normalizedExplanation =
                output.accessibleExplanation().toLowerCase(java.util.Locale.ROOT);

        return PROHIBITED_OPERATIONAL_TERMS.stream()
                .noneMatch(normalizedExplanation::contains);
    }
}
