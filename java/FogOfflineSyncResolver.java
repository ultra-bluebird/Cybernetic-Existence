package augmentedhub.fog;

import java.time.Instant;
import java.util.Objects;

public final class FogOfflineSyncResolver {

    public enum SyncResolution {
        APPLY_REMOTE_APPEND,
        APPLY_LOCAL_APPEND,
        NO_CHANGE,
        HUMAN_REVIEW_REQUIRED,
        EXPIRED_DO_NOT_UPLOAD
    }

    public record SyncRecord(
            String queueId,
            String eventHash,
            long sequenceNumber,
            Instant eventTimestamp,
            Instant expiresAt,
            boolean contentPresent,
            boolean humanSigned
    ) {
        public SyncRecord {
            requireOpaque(queueId, "queueId");
            requireDigest(eventHash, "eventHash");
            Objects.requireNonNull(eventTimestamp, "eventTimestamp");
            Objects.requireNonNull(expiresAt, "expiresAt");

            if (expiresAt.isBefore(eventTimestamp)
                    || expiresAt.equals(eventTimestamp)) {
                throw new IllegalArgumentException(
                        "expiresAt must be later than eventTimestamp"
                );
            }
        }
    }

    private FogOfflineSyncResolver() {}

    public static SyncResolution resolve(
            SyncRecord local,
            SyncRecord remote,
            Instant now
    ) {
        Objects.requireNonNull(local, "local");
        Objects.requireNonNull(remote, "remote");
        Objects.requireNonNull(now, "now");

        if (!local.queueId().equals(remote.queueId())) {
            throw new IllegalArgumentException(
                    "Cannot synchronize distinct queue IDs"
            );
        }

        if (!now.isBefore(local.expiresAt())
                || !now.isBefore(remote.expiresAt())) {
            return SyncResolution.EXPIRED_DO_NOT_UPLOAD;
        }

        if (local.eventHash().equals(remote.eventHash())) {
            return SyncResolution.NO_CHANGE;
        }

        if (local.sequenceNumber() == remote.sequenceNumber()) {
            return SyncResolution.HUMAN_REVIEW_REQUIRED;
        }

        if (local.humanSigned() && remote.humanSigned()) {
            return SyncResolution.HUMAN_REVIEW_REQUIRED;
        }

        return local.sequenceNumber() > remote.sequenceNumber()
                ? SyncResolution.APPLY_LOCAL_APPEND
                : SyncResolution.APPLY_REMOTE_APPEND;
    }

    private static void requireOpaque(String value, String name) {
        if (value == null
                || !value.matches("^[A-Za-z0-9_-]{8,128}$")) {
            throw new IllegalArgumentException(
                    name + " must be an opaque bounded identifier"
            );
        }
    }

    private static void requireDigest(String value, String name) {
        if (value == null
                || !value.matches("^[0-9a-f]{64}$")) {
            throw new IllegalArgumentException(
                    name + " must be a SHA-256 hex digest"
            );
        }
    }
}
