package org.augmentedhub.hearthline;

import java.util.EnumSet;
import java.util.Objects;
import java.util.Set;

public final class IdentityGuardianCapabilityValidator {
    public enum Capability {
        NOTIFY_ON_CREDENTIAL_CONTINUITY_EVENT,
        CO_SIGN_CREDENTIAL_CONTINUITY,
        RECEIVE_SAFETY_PLAN_CHECKIN,
        RECEIVE_ACCOUNT_SAFETY_NOTICE,
        WITHDRAW_GUARDIAN_CONSENT
    }

    public enum ProhibitedCapability {
        READ_MESSAGES,
        VIEW_PROFILE,
        VIEW_PHOTOS,
        SEE_MATCHES,
        READ_CONSENT_SCOPES,
        READ_RECOVERY_CONTEXT,
        READ_HEALTH_CONTEXT,
        READ_ACCOUNT_HISTORY,
        READ_SECURITY_HISTORY,
        READ_CREDENTIAL_METADATA,
        READ_RECOVERY_CODES,
        READ_RECOVERY_SHARES,
        ADD_PASSKEY,
        REMOVE_PASSKEY,
        CHANGE_PRIVACY_SCOPE,
        CHANGE_PACING,
        PAUSE_ACCOUNT,
        RESUME_ACCOUNT,
        SEND_MESSAGE,
        REPORT_ON_BEHALF_OF_USER,
        LINK_EXTERNAL_PROVIDER,
        EXPORT_ACCOUNT_DATA,
        TRACK_LOCATION,
        REQUIRE_CHECKIN,
        LEARN_RECOVERY_STATUS
    }

    private static final Set<Capability> ALLOWED_CAPABILITIES =
            EnumSet.allOf(Capability.class);

    public ValidationResult validateRequestedCapabilities(
            Set<Capability> requestedCapabilities,
            Set<ProhibitedCapability> prohibitedCapabilities
    ) {
        Objects.requireNonNull(requestedCapabilities, "requestedCapabilities");
        Objects.requireNonNull(prohibitedCapabilities, "prohibitedCapabilities");

        if (requestedCapabilities.isEmpty()) {
            return ValidationResult.rejected("NO_GUARDIAN_CAPABILITY_SELECTED");
        }

        if (!ALLOWED_CAPABILITIES.containsAll(requestedCapabilities)) {
            return ValidationResult.rejected("UNSUPPORTED_GUARDIAN_CAPABILITY");
        }

        if (!prohibitedCapabilities.isEmpty()) {
            return ValidationResult.rejected("PROHIBITED_GUARDIAN_CAPABILITY");
        }

        return ValidationResult.accepted();
    }

    public boolean mayAccessProfile() {
        return false;
    }

    public boolean mayAccessMessages() {
        return false;
    }

    public boolean mayAccessMatches() {
        return false;
    }

    public boolean mayAccessRecoveryContext() {
        return false;
    }

    public boolean mayAccessCredentialMaterial() {
        return false;
    }

    public boolean mayControlAccount() {
        return false;
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
