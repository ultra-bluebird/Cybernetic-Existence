package org.augmentedhub.continuity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public final class SystemStateSnapshot {
    public record PolicyReference(
        String policyId,
        String revision,
        String classification
    ) {
        public PolicyReference {
            requireNonBlank(policyId, "policyId");
            requireNonBlank(revision, "revision");
            requireNonBlank(classification, "classification");
        }
    }

    public record Authorization(
        String authorizationType,
        List<String> actorReferences
    ) {
        public Authorization {
            requireNonBlank(authorizationType, "authorizationType");

            if (actorReferences == null || actorReferences.isEmpty()) {
                throw new IllegalArgumentException(
                    "actorReferences must contain at least one reference"
                );
            }

            actorReferences = actorReferences.stream()
                .peek(reference -> requireNonBlank(reference, "actorReference"))
                .sorted()
                .toList();
        }
    }

    public record Snapshot(
        UUID snapshotId,
        long sequence,
        Instant timestamp,
        String subjectDid,
        String configurationVersion,
        List<PolicyReference> activePolicies,
        String policyDigest,
        String previousStateDigest,
        List<String> observerReferences,
        Authorization authorization,
        String classification,
        String stateDigest
    ) {}

    private SystemStateSnapshot() {}

    public static Snapshot create(
        long sequence,
        Instant timestamp,
        String subjectDid,
        String configurationVersion,
        List<PolicyReference> activePolicies,
        String previousStateDigest,
        List<String> observerReferences,
        Authorization authorization,
        String classification
    ) {
        if (sequence < 0) {
            throw new IllegalArgumentException("sequence must be non-negative");
        }

        Objects.requireNonNull(timestamp, "timestamp must not be null");
        requireNonBlank(subjectDid, "subjectDid");
        requireNonBlank(configurationVersion, "configurationVersion");
        requireNonBlank(classification, "classification");
        Objects.requireNonNull(authorization, "authorization must not be null");

        if (activePolicies == null || activePolicies.isEmpty()) {
            throw new IllegalArgumentException(
                "activePolicies must contain at least one policy"
            );
        }

        List<PolicyReference> canonicalPolicies = activePolicies.stream()
            .sorted(
                Comparator.comparing(PolicyReference::policyId)
                    .thenComparing(PolicyReference::revision)
                    .thenComparing(PolicyReference::classification)
            )
            .toList();

        List<String> canonicalObservers =
            observerReferences == null
                ? List.of()
                : observerReferences.stream()
                    .peek(reference -> requireNonBlank(reference, "observerReference"))
                    .distinct()
                    .sorted()
                    .toList();

        String policyDigest = sha384(
            canonicalPolicies.stream()
                .map(policy -> String.join(
                    "|",
                    policy.policyId(),
                    policy.revision(),
                    policy.classification()
                ))
                .reduce("", (left, right) -> left + "\n" + right)
        );

        String canonicalState = String.join(
            "|",
            "AUGMENTED_HUB_SYSTEM_STATE_SNAPSHOT_V1",
            Long.toString(sequence),
            timestamp.toString(),
            subjectDid,
            configurationVersion,
            policyDigest,
            previousStateDigest == null ? "" : previousStateDigest,
            String.join(",", canonicalObservers),
            authorization.authorizationType(),
            String.join(",", authorization.actorReferences()),
            classification
        );

        String stateDigest = sha384(canonicalState);

        return new Snapshot(
            UUID.randomUUID(),
            sequence,
            timestamp,
            subjectDid,
            configurationVersion,
            canonicalPolicies,
            policyDigest,
            previousStateDigest,
            canonicalObservers,
            authorization,
            classification,
            stateDigest
        );
    }

    public static boolean verify(Snapshot snapshot) {
        Objects.requireNonNull(snapshot, "snapshot must not be null");

        Snapshot recomputed = create(
            snapshot.sequence(),
            snapshot.timestamp(),
            snapshot.subjectDid(),
            snapshot.configurationVersion(),
            snapshot.activePolicies(),
            snapshot.previousStateDigest(),
            snapshot.observerReferences(),
            snapshot.authorization(),
            snapshot.classification()
        );

        return recomputed.policyDigest().equals(snapshot.policyDigest())
            && recomputed.stateDigest().equals(snapshot.stateDigest());
    }

    private static String sha384(String value) {
        try {
            byte[] digest = MessageDigest
                .getInstance("SHA-384")
                .digest(value.getBytes(StandardCharsets.UTF_8));

            StringBuilder result = new StringBuilder(digest.length * 2);

            for (byte item : digest) {
                result.append(String.format("%02x", item));
            }

            return result.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                "SHA-384 must be available in the Java runtime",
                exception
            );
        }
    }

    private static void requireNonBlank(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
    }
}
