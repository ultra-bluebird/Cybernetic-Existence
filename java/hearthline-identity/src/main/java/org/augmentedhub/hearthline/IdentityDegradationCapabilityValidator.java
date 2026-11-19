package org.augmentedhub.hearthline;

import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class IdentityDegradationCapabilityValidator {
    public enum AccessState {
        FULL_ACCESS,
        LIMITED_ACCESS,
        READ_ONLY,
        CONTINUITY_AVAILABLE,
        CONTINUITY_ACTIVE,
        RESTORED
    }

    public enum Capability {
        VIEW_OWN_SETTINGS,
        VIEW_AVAILABLE_CONNECTION_HISTORY,
        READ_AVAILABLE_MESSAGES,
        PAUSE_ACTIVITY,
        REVOKE_CONSENT,
        BLOCK_CONNECTION,
        SUBMIT_SAFETY_REPORT,
        VIEW_SECURITY_HISTORY,
        VIEW_CONTINUITY_GUIDANCE,
        END_CURRENT_SESSION,
        CLEAR_LOCAL_DATA,
        REQUEST_REVIEW,
        SAVE_LOCAL_DRAFT,
        SEND_MESSAGE,
        EXPRESS_INTEREST,
        EXPAND_DISCLOSURE_SCOPE,
        REVEAL_CONTACT_DETAILS,
        EXPORT_ACCOUNT_DATA,
        LINK_EXTERNAL_PROVIDER,
        ADD_AUTHENTICATOR,
        REMOVE_AUTHENTICATOR,
        CHANGE_SUPPORT_CONTACTS,
        CLOSE_ACCOUNT
    }

    private static final Set<Capability> UNIVERSAL_SAFETY_CAPABILITIES = EnumSet.of(
            Capability.PAUSE_ACTIVITY,
            Capability.REVOKE_CONSENT,
            Capability.BLOCK_CONNECTION,
            Capability.SUBMIT_SAFETY_REPORT,
            Capability.VIEW_OWN_SETTINGS,
            Capability.VIEW_SECURITY_HISTORY,
            Capability.VIEW_CONTINUITY_GUIDANCE,
            Capability.END_CURRENT_SESSION,
            Capability.CLEAR_LOCAL_DATA,
            Capability.REQUEST_REVIEW
    );

    private static final Map<AccessState, Set<Capability>> CAPABILITIES =
            createCapabilityMatrix();

    public boolean isAllowed(
            AccessState state,
            Capability capability
    ) {
        Objects.requireNonNull(state, "state");
        Objects.requireNonNull(capability, "capability");

        return CAPABILITIES.get(state).contains(capability);
    }

    public ValidationResult validateSafetyFloor() {
        for (AccessState state : AccessState.values()) {
            if (!CAPABILITIES.get(state).containsAll(UNIVERSAL_SAFETY_CAPABILITIES)) {
                return ValidationResult.rejected(
                        "UNIVERSAL_SAFETY_CAPABILITY_MISSING_" + state.name()
                );
            }
        }

        return ValidationResult.accepted();
    }

    public ValidationResult validateNoOutboundAccessInDegradedStates() {
        Set<Capability> outboundCapabilities = EnumSet.of(
                Capability.SEND_MESSAGE,
                Capability.EXPRESS_INTEREST,
                Capability.EXPAND_DISCLOSURE_SCOPE,
                Capability.REVEAL_CONTACT_DETAILS,
                Capability.EXPORT_ACCOUNT_DATA,
                Capability.LINK_EXTERNAL_PROVIDER,
                Capability.ADD_AUTHENTICATOR,
                Capability.REMOVE_AUTHENTICATOR,
                Capability.CHANGE_SUPPORT_CONTACTS,
                Capability.CLOSE_ACCOUNT
        );

        for (AccessState state : EnumSet.of(
                AccessState.READ_ONLY,
                AccessState.CONTINUITY_AVAILABLE,
                AccessState.CONTINUITY_ACTIVE
        )) {
            Set<Capability> permitted = CAPABILITIES.get(state);

            for (Capability capability : outboundCapabilities) {
                if (permitted.contains(capability)) {
                    return ValidationResult.rejected(
                            "OUTBOUND_CAPABILITY_ALLOWED_IN_" + state.name()
                    );
                }
            }
        }

        return ValidationResult.accepted();
    }

    private static Map<AccessState, Set<Capability>> createCapabilityMatrix() {
        Map<AccessState, Set<Capability>> matrix =
                new EnumMap<>(AccessState.class);

        matrix.put(AccessState.FULL_ACCESS, EnumSet.allOf(Capability.class));

        matrix.put(AccessState.LIMITED_ACCESS, EnumSet.of(
                Capability.VIEW_OWN_SETTINGS,
                Capability.VIEW_AVAILABLE_CONNECTION_HISTORY,
                Capability.READ_AVAILABLE_MESSAGES,
                Capability.PAUSE_ACTIVITY,
                Capability.REVOKE_CONSENT,
                Capability.BLOCK_CONNECTION,
                Capability.SUBMIT_SAFETY_REPORT,
                Capability.VIEW_SECURITY_HISTORY,
                Capability.VIEW_CONTINUITY_GUIDANCE,
                Capability.END_CURRENT_SESSION,
                Capability.CLEAR_LOCAL_DATA,
                Capability.REQUEST_REVIEW,
                Capability.SAVE_LOCAL_DRAFT
        ));

        matrix.put(AccessState.READ_ONLY, EnumSet.of(
                Capability.VIEW_OWN_SETTINGS,
                Capability.VIEW_AVAILABLE_CONNECTION_HISTORY,
                Capability.READ_AVAILABLE_MESSAGES,
                Capability.PAUSE_ACTIVITY,
                Capability.REVOKE_CONSENT,
                Capability.BLOCK_CONNECTION,
                Capability.SUBMIT_SAFETY_REPORT,
                Capability.VIEW_SECURITY_HISTORY,
                Capability.VIEW_CONTINUITY_GUIDANCE,
                Capability.END_CURRENT_SESSION,
                Capability.CLEAR_LOCAL_DATA,
                Capability.REQUEST_REVIEW,
                Capability.SAVE_LOCAL_DRAFT
        ));

        matrix.put(AccessState.CONTINUITY_AVAILABLE, EnumSet.of(
                Capability.VIEW_OWN_SETTINGS,
                Capability.PAUSE_ACTIVITY,
                Capability.REVOKE_CONSENT,
                Capability.BLOCK_CONNECTION,
                Capability.SUBMIT_SAFETY_REPORT,
                Capability.VIEW_SECURITY_HISTORY,
                Capability.VIEW_CONTINUITY_GUIDANCE,
                Capability.END_CURRENT_SESSION,
                Capability.CLEAR_LOCAL_DATA,
                Capability.REQUEST_REVIEW
        ));

        matrix.put(AccessState.CONTINUITY_ACTIVE, EnumSet.of(
                Capability.VIEW_OWN_SETTINGS,
                Capability.PAUSE_ACTIVITY,
                Capability.REVOKE_CONSENT,
                Capability.BLOCK_CONNECTION,
                Capability.SUBMIT_SAFETY_REPORT,
                Capability.VIEW_SECURITY_HISTORY,
                Capability.VIEW_CONTINUITY_GUIDANCE,
                Capability.END_CURRENT_SESSION,
                Capability.CLEAR_LOCAL_DATA,
                Capability.REQUEST_REVIEW,
                Capability.SAVE_LOCAL_DRAFT
        ));

        matrix.put(AccessState.RESTORED, EnumSet.allOf(Capability.class));

        return Map.copyOf(matrix);
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
