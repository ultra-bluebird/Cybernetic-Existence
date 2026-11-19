package org.augmentedhub.smartcity;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public final class AnonymousTraversalRequestValidator {
    public record PrivacyDeclaration(
        boolean containsRawBiometrics,
        boolean containsPrivateHealthData,
        boolean containsCyberRankData,
        boolean containsPersistentIdentifier,
        int retentionMinutes
    ) {}

    public record TraversalRequest(
        String requestId,
        String anonymousToken,
        String purpose,
        Instant issuedAt,
        Instant expiresAt,
        Set<String> accessibilityFlags,
        PrivacyDeclaration privacy
    ) {
        public TraversalRequest {
            Objects.requireNonNull(requestId, "requestId must not be null");
            Objects.requireNonNull(anonymousToken, "anonymousToken must not be null");
            Objects.requireNonNull(purpose, "purpose must not be null");
            Objects.requireNonNull(issuedAt, "issuedAt must not be null");
            Objects.requireNonNull(expiresAt, "expiresAt must not be null");
            Objects.requireNonNull(accessibilityFlags, "accessibilityFlags must not be null");
            Objects.requireNonNull(privacy, "privacy must not be null");
        }
    }

    public record ValidationResult(
        boolean accepted,
        List<String> violations
    ) {}

    private static final Set<String> ALLOWED_PURPOSES = Set.of(
        "temporary-accessible-route-selection",
        "temporary-intersection-assistance",
        "temporary-transit-accessibility-notice",
        "temporary-public-space-accessibility-request"
    );

    private static final Set<String> ALLOWED_FLAGS = Set.of(
        "shade-preference",
        "heat-risk-preference",
        "step-free-route-required",
        "curb-ramp-required",
        "elevator-required",
        "quiet-route-preference",
        "rest-location-preference",
        "human-assistance-option-requested"
    );

    private static final int MAX_RETENTION_MINUTES = 120;
    private static final Duration MAX_TOKEN_LIFETIME = Duration.ofHours(2);

    private AnonymousTraversalRequestValidator() {}

    public static ValidationResult validate(TraversalRequest request) {
        var violations = new java.util.ArrayList<String>();

        if (request.requestId().isBlank()) {
            violations.add("requestId must not be blank");
        }

        if (request.anonymousToken().length() < 32) {
            violations.add("anonymousToken must contain at least 32 characters");
        }

        if (!ALLOWED_PURPOSES.contains(request.purpose())) {
            violations.add("purpose is not allowed");
        }

        if (!request.expiresAt().isAfter(request.issuedAt())) {
            violations.add("expiresAt must be after issuedAt");
        }

        if (Duration.between(request.issuedAt(), request.expiresAt())
            .compareTo(MAX_TOKEN_LIFETIME) > 0) {
            violations.add("token lifetime exceeds the two-hour maximum");
        }

        if (request.privacy().containsRawBiometrics()) {
            violations.add("raw biometrics are prohibited");
        }

        if (request.privacy().containsPrivateHealthData()) {
            violations.add("private health data are prohibited");
        }

        if (request.privacy().containsCyberRankData()) {
            violations.add("CyberRank data are prohibited");
        }

        if (request.privacy().containsPersistentIdentifier()) {
            violations.add("persistent identifiers are prohibited");
        }

        if (
            request.privacy().retentionMinutes() < 1 ||
            request.privacy().retentionMinutes() > MAX_RETENTION_MINUTES
        ) {
            violations.add("retentionMinutes must be within 1 to 120");
        }

        for (String flag : request.accessibilityFlags()) {
            if (!ALLOWED_FLAGS.contains(flag)) {
                violations.add("unsupported accessibility flag: " + flag);
            }
        }

        return new ValidationResult(violations.isEmpty(), List.copyOf(violations));
    }
}
