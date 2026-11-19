package org.augmentedhub.hearthline;

import java.util.List;
import java.util.Locale;
import java.util.Objects;

public final class MemoryAidNotificationValidator {
    private static final List<String> PROHIBITED_TERMS = List.of(
            "password",
            "passkey",
            "private key",
            "recovery code",
            "verification code",
            "one-time code",
            "token",
            "refresh token",
            "trusted contact",
            "security key",
            "credential id",
            "recovery share",
            "match",
            "message from",
            "recovery status"
    );

    public ValidationResult validate(String notificationText) {
        Objects.requireNonNull(notificationText, "notificationText");

        String normalized = notificationText.toLowerCase(Locale.ROOT);

        if (normalized.isBlank()) {
            return ValidationResult.rejected("EMPTY_NOTIFICATION");
        }

        for (String prohibited : PROHIBITED_TERMS) {
            if (normalized.contains(prohibited)) {
                return ValidationResult.rejected("PROHIBITED_REMINDER_CONTENT");
            }
        }

        if (notificationText.length() > 160) {
            return ValidationResult.rejected("NOTIFICATION_TOO_LONG");
        }

        return ValidationResult.accepted();
    }

    public record ValidationResult(boolean accepted, String code) {
        public static ValidationResult accepted() {
            return new ValidationResult(true, "ACCEPTED");
        }

        public static ValidationResult rejected(String code) {
            return new ValidationResult(false, code);
        }
    }
}
