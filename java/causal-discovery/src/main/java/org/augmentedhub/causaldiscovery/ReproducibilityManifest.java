package org.augmentedhub.causaldiscovery;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class ReproducibilityManifest {
    public record Manifest(
        String manifestId,
        String datasetId,
        String datasetVersion,
        String graphRunId,
        String searchMethod,
        String temporalConstraintVersion,
        String censoringMethodVersion,
        String multipleTestingMethod,
        List<String> variableNames,
        String sourceDigest,
        Instant createdAt
    ) {
        public Manifest {
            requireText(manifestId, "manifestId");
            requireText(datasetId, "datasetId");
            requireText(datasetVersion, "datasetVersion");
            requireText(graphRunId, "graphRunId");
            requireText(searchMethod, "searchMethod");
            requireText(temporalConstraintVersion, "temporalConstraintVersion");
            requireText(censoringMethodVersion, "censoringMethodVersion");
            requireText(multipleTestingMethod, "multipleTestingMethod");
            requireText(sourceDigest, "sourceDigest");
            Objects.requireNonNull(variableNames, "variableNames");
            Objects.requireNonNull(createdAt, "createdAt");

            if (variableNames.isEmpty()) {
                throw new IllegalArgumentException("variableNames must not be empty");
            }

            for (String variableName : variableNames) {
                requireText(variableName, "variableNames entry");
            }
        }
    }

    private ReproducibilityManifest() {
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must be non-empty");
        }
    }
}
