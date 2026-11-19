package org.augmentedhub.corrections;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Objects;
import java.util.UUID;

public final class CorrectionReceiptGenerator {
    public record ReceiptRequest(
            String caseReference,
            String submissionEventDigest,
            String policyRevision,
            Instant issuedAt
    ) {
        public ReceiptRequest {
            Objects.requireNonNull(caseReference, "caseReference");
            Objects.requireNonNull(submissionEventDigest, "submissionEventDigest");
            Objects.requireNonNull(policyRevision, "policyRevision");
            Objects.requireNonNull(issuedAt, "issuedAt");

            if (caseReference.isBlank()
                    || submissionEventDigest.isBlank()
                    || policyRevision.isBlank()) {
                throw new IllegalArgumentException("Receipt request fields must be present.");
            }
        }
    }

    public record CorrectionReceipt(
            String receiptReference,
            String caseReferenceDigest,
            String submissionEventDigest,
            String receiptDigest,
            Instant issuedAt,
            String policyRevision,
            String accessibleExplanation
    ) {}

    public CorrectionReceipt issue(ReceiptRequest request) {
        Objects.requireNonNull(request, "request");

        String receiptReference = UUID.randomUUID().toString();
        String caseReferenceDigest = sha256(request.caseReference());
        String receiptDigest = sha256(String.join("\u001f",
                receiptReference,
                caseReferenceDigest,
                request.submissionEventDigest(),
                request.policyRevision(),
                request.issuedAt().toString()));

        return new CorrectionReceipt(
                receiptReference,
                caseReferenceDigest,
                request.submissionEventDigest(),
                receiptDigest,
                request.issuedAt(),
                request.policyRevision(),
                "This receipt confirms that a correction submission was recorded. "
                        + "It does not disclose case details or determine the review outcome.");
    }

    private static String sha256(String value) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable.", exception);
        }
    }
}
