package org.augmentedhub.hearthline;

import java.util.EnumSet;
import java.util.Objects;
import java.util.Set;

public final class IdentityIsolationValidator {
    public enum SourceSystem {
        ANCHOR_LINE,
        IDENTITY_ACCESS_COORDINATOR,
        DEVICE_GROUP,
        PROMPT_LOAD_POLICY,
        COMMON_GROUND,
        TRUE_COMPASS,
        LANTERN,
        HEARTH_CHAT,
        STEADY_PATH,
        WAYPOINT,
        BRIDGE_ADAPTERS,
        RECOVERY_EXPRESSION,
        RECIPIENT_PERSONA,
        MATCHING,
        PROFILE_PRESENTATION,
        PERSON_LEVEL_ANALYTICS,
        EXTERNAL_PROVIDER
    }

    private static final Set<SourceSystem> DEVICE_GROUP_DENIED_READERS = EnumSet.of(
            SourceSystem.TRUE_COMPASS,
            SourceSystem.LANTERN,
            SourceSystem.HEARTH_CHAT,
            SourceSystem.COMMON_GROUND,
            SourceSystem.STEADY_PATH,
            SourceSystem.WAYPOINT,
            SourceSystem.BRIDGE_ADAPTERS,
            SourceSystem.RECOVERY_EXPRESSION,
            SourceSystem.RECIPIENT_PERSONA,
            SourceSystem.MATCHING,
            SourceSystem.PROFILE_PRESENTATION,
            SourceSystem.PERSON_LEVEL_ANALYTICS,
            SourceSystem.EXTERNAL_PROVIDER
    );

    private static final Set<SourceSystem> PROMPT_LOAD_DENIED_READERS = EnumSet.of(
            SourceSystem.TRUE_COMPASS,
            SourceSystem.LANTERN,
            SourceSystem.RECIPIENT_PERSONA,
            SourceSystem.RECOVERY_EXPRESSION,
            SourceSystem.BRIDGE_ADAPTERS,
            SourceSystem.MATCHING,
            SourceSystem.PROFILE_PRESENTATION,
            SourceSystem.PERSON_LEVEL_ANALYTICS,
            SourceSystem.EXTERNAL_PROVIDER
    );

    public ValidationResult validateDeviceGroupRead(SourceSystem requester) {
        Objects.requireNonNull(requester, "requester");

        if (DEVICE_GROUP_DENIED_READERS.contains(requester)) {
            return ValidationResult.rejected(
                    "DEVICE_GROUP_READ_DENIED_" + requester.name()
            );
        }

        return ValidationResult.accepted();
    }

    public ValidationResult validatePromptLoadRead(SourceSystem requester) {
        Objects.requireNonNull(requester, "requester");

        if (PROMPT_LOAD_DENIED_READERS.contains(requester)) {
            return ValidationResult.rejected(
                    "PROMPT_LOAD_READ_DENIED_" + requester.name()
            );
        }

        return ValidationResult.accepted();
    }

    public ValidationResult validateIdentityAccessUse(
            boolean matchingUseAllowed,
            boolean rankingUseAllowed,
            boolean profileVisibilityUseAllowed,
            boolean recoveryAttributeUsed,
            boolean healthAttributeUsed,
            boolean behavioralInferenceUsed,
            boolean externalActionAuthorized
    ) {
        if (matchingUseAllowed
                || rankingUseAllowed
                || profileVisibilityUseAllowed
                || recoveryAttributeUsed
                || healthAttributeUsed
                || behavioralInferenceUsed
                || externalActionAuthorized) {
            return ValidationResult.rejected(
                    "IDENTITY_ACCESS_NON_CONVERSION_INVARIANT_VIOLATED"
            );
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
