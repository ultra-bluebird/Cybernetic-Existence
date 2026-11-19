package augmentedhub.fog;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Objects;

public final class FogStateHashChain {

    public static final String DOMAIN =
            "AugmentedHub.FOG.StateLog.v1";

    public static final String CANONICALIZATION_VERSION =
            "canonical-fields-v1";

    public static final String GENESIS_HASH =
            "0000000000000000000000000000000000000000000000000000000000000000";

    public record StateEvent(
            long sequenceNumber,
            String eventId,
            String queueId,
            String previousState,
            String resultingState,
            Instant observedAtUtc,
            String policyReference,
            String modelVersionReference,
            String aggregationWindowReference,
            int sourceHexResolution,
            int appliedHexResolution,
            String opaqueSpatialScope,
            String reasonCode,
            String retentionClass,
            String nonce
    ) {
        public StateEvent {
            if (sequenceNumber < 0L) {
                throw new IllegalArgumentException(
                        "sequenceNumber must be non-negative"
                );
            }

            requireOpaqueIdentifier(eventId, "eventId");
            requireOpaqueIdentifier(queueId, "queueId");
            requireStateToken(previousState, "previousState");
            requireStateToken(resultingState, "resultingState");
            Objects.requireNonNull(observedAtUtc, "observedAtUtc");
            requireOpaqueIdentifier(policyReference, "policyReference");
            requireOpaqueIdentifier(modelVersionReference,
                    "modelVersionReference");
            requireOpaqueIdentifier(aggregationWindowReference,
                    "aggregationWindowReference");
            requireOpaqueIdentifier(opaqueSpatialScope,
                    "opaqueSpatialScope");
            requireStateToken(reasonCode, "reasonCode");
            requireStateToken(retentionClass, "retentionClass");
            requireOpaqueIdentifier(nonce, "nonce");

            if (sourceHexResolution < 0 || sourceHexResolution > 15) {
                throw new IllegalArgumentException(
                        "sourceHexResolution must be within [0, 15]"
                );
            }

            if (appliedHexResolution < 0 || appliedHexResolution > 15) {
                throw new IllegalArgumentException(
                        "appliedHexResolution must be within [0, 15]"
                );
            }
        }
    }

    public record HashedStateEvent(
            StateEvent event,
            String previousHash,
            String eventHash
    ) {
        public HashedStateEvent {
            requireDigest(previousHash, "previousHash");
            requireDigest(eventHash, "eventHash");
        }
    }

    private FogStateHashChain() {
    }

    public static HashedStateEvent append(
            StateEvent event,
            String previousHash
    ) {
        Objects.requireNonNull(event, "event");
        requireDigest(previousHash, "previousHash");

        byte[] digest = sha256(
                frameUtf8(DOMAIN),
                frameUtf8(CANONICALIZATION_VERSION),
                frameBytes(hexToBytes(previousHash)),
                frameBytes(canonicalEventData(event)),
                frameUtf8(event.nonce())
        );

        return new HashedStateEvent(
                event,
                previousHash,
                HexFormat.of().formatHex(digest)
        );
    }

    public static boolean verify(HashedStateEvent entry) {
        Objects.requireNonNull(entry, "entry");

        HashedStateEvent recomputed = append(
                entry.event(),
                entry.previousHash()
        );

        return MessageDigest.isEqual(
                hexToBytes(entry.eventHash()),
                hexToBytes(recomputed.eventHash())
        );
    }

    public static boolean verifyLink(
            HashedStateEvent prior,
            HashedStateEvent current
    ) {
        Objects.requireNonNull(prior, "prior");
        Objects.requireNonNull(current, "current");

        return prior.event().queueId()
                    .equals(current.event().queueId())
                && current.event().sequenceNumber()
                    == prior.event().sequenceNumber() + 1L
                && current.previousHash()
                    .equals(prior.eventHash())
                && verify(prior)
                && verify(current);
    }

    private static byte[] canonicalEventData(StateEvent event) {
        String canonical = String.join("\n",
                "sequence_number=" + event.sequenceNumber(),
                "event_id=" + event.eventId(),
                "queue_id=" + event.queueId(),
                "previous_state=" + event.previousState(),
                "resulting_state=" + event.resultingState(),
                "observed_at_utc=" + event.observedAtUtc(),
                "policy_reference=" + event.policyReference(),
                "model_version_reference=" + event.modelVersionReference(),
                "aggregation_window_reference="
                        + event.aggregationWindowReference(),
                "source_hex_resolution=" + event.sourceHexResolution(),
                "applied_hex_resolution=" + event.appliedHexResolution(),
                "opaque_spatial_scope=" + event.opaqueSpatialScope(),
                "reason_code=" + event.reasonCode(),
                "retention_class=" + event.retentionClass()
        );

        return canonical.getBytes(StandardCharsets.UTF_8);
    }

    private static byte[] frameUtf8(String value) {
        return frameBytes(value.getBytes(StandardCharsets.UTF_8));
    }

    private static byte[] frameBytes(byte[] value) {
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            output.write(ByteBuffer.allocate(Integer.BYTES)
                    .putInt(value.length)
                    .array());
            output.write(value);
            return output.toByteArray();
        } catch (java.io.IOException error) {
            throw new IllegalStateException(
                    "In-memory framing unexpectedly failed",
                    error
            );
        }
    }

    private static byte[] sha256(byte[]... fields) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");

            for (byte[] field : fields) {
                digest.update(field);
            }

            return digest.digest();
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException(
                    "SHA-256 must be available in the Java runtime",
                    error
            );
        }
    }

    private static byte[] hexToBytes(String digest) {
        return HexFormat.of().parseHex(digest);
    }

    private static void requireDigest(
            String value,
            String fieldName
    ) {
        if (value == null
                || !value.matches("^[0-9a-f]{64}$")) {
            throw new IllegalArgumentException(
                    fieldName + " must be a lowercase SHA-256 hex digest"
            );
        }
    }

    private static void requireOpaqueIdentifier(
            String value,
            String fieldName
    ) {
        if (value == null
                || !value.matches("^[A-Za-z0-9_-]{8,128}$")) {
            throw new IllegalArgumentException(
                    fieldName + " must be an opaque bounded identifier"
            );
        }
    }

    private static void requireStateToken(
            String value,
            String fieldName
    ) {
        if (value == null
                || !value.matches("^[A-Z_]{3,80}$")) {
            throw new IllegalArgumentException(
                    fieldName + " must use uppercase token form"
            );
        }
    }
}
