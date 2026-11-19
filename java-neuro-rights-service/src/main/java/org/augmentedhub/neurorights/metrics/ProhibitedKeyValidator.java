package org.augmentedhub.neurorights.metrics;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

public final class ProhibitedKeyValidator {
    /*
     * GENERATED FROM THE CANONICAL METRIC-DISPATCH CONTRACT.
     *
     * This declaration is intentionally a structural placeholder. The build
     * must fail if the generated source does not contain the exact canonical
     * policy set and matching semantics.
     */
    private static final List<String> PROHIBITED_KEY_TOKENS = List.of(
        "person",
        "individual",
        "household",
        "identity",
        "name",
        "email",
        "phone",
        "address",
        "device",
        "macaddress",
        "bluetooth",
        "wifi",
        "trajectory",
        "locationhistory",
        "image",
        "audio",
        "face",
        "gait",
        "health",
        "medical",
        "neural",
        "biometric",
        "disability"
    );

    private ProhibitedKeyValidator() {
    }

    public static ValidationResult validate(final Object value) {
        return validate(value, "$");
    }

    public static String normalizeKey(final String value) {
        Objects.requireNonNull(value, "value");

        final StringBuilder normalized = new StringBuilder(value.length());

        for (int index = 0; index < value.length(); index++) {
            final char character = value.charAt(index);

            if (Character.isLetterOrDigit(character)) {
                normalized.append(Character.toLowerCase(character));
            }
        }

        return normalized.toString();
    }

    public static Optional<String> prohibitedTokenForKey(final String key) {
        final String normalizedKey = normalizeKey(key);

        if (normalizedKey.isEmpty()) {
            return Optional.of("non_string_or_empty_key");
        }

        return PROHIBITED_KEY_TOKENS.stream()
            .map(ProhibitedKeyValidator::normalizeKey)
            .filter(token -> !token.isEmpty())
            .filter(normalizedKey::contains)
            .findFirst();
    }

    @SuppressWarnings("unchecked")
    private static ValidationResult validate(
        final Object value,
        final String path
    ) {
        if (value instanceof Map<?, ?> rawMap) {
            for (final Map.Entry<?, ?> entry : rawMap.entrySet()) {
                if (!(entry.getKey() instanceof String key)) {
                    return ValidationResult.rejected(
                        path,
                        "non_string_key",
                        "non_string_key"
                    );
                }

                final Optional<String> prohibitedToken =
                    prohibitedTokenForKey(key);

                if (prohibitedToken.isPresent()) {
                    return ValidationResult.rejected(
                        path + "." + key,
                        "prohibited_key",
                        prohibitedToken.get()
                    );
                }

                final ValidationResult nestedResult = validate(
                    entry.getValue(),
                    path + "." + key
                );

                if (!nestedResult.allowed()) {
                    return nestedResult;
                }
            }

            return ValidationResult.allowed();
        }

        if (value instanceof List<?> list) {
            for (int index = 0; index < list.size(); index++) {
                final ValidationResult nestedResult = validate(
                    list.get(index),
                    path + "[" + index + "]"
                );

                if (!nestedResult.allowed()) {
                    return nestedResult;
                }
            }
        }

        return ValidationResult.allowed();
    }

    public record ValidationResult(
        boolean allowed,
        String path,
        String reason,
        String matchedToken
    ) {
        public static ValidationResult allowed() {
            return new ValidationResult(true, null, null, null);
        }

        public static ValidationResult rejected(
            final String path,
            final String reason,
            final String matchedToken
        ) {
            return new ValidationResult(
                false,
                Objects.requireNonNull(path, "path"),
                Objects.requireNonNull(reason, "reason"),
                Objects.requireNonNull(matchedToken, "matchedToken")
            );
        }
    }
}
