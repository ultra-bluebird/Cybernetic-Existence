package org.augmentedhub.governance;

import java.util.EnumSet;
import java.util.Objects;
import java.util.Set;

public final class NonActuatingResearchGate {
    public enum RequestedCapability {
        DOCUMENTATION,
        DATA_VALIDATION,
        FORMAL_VERIFICATION,
        OFFLINE_SIMULATION,
        ENVIRONMENTAL_ROUTE_PLANNING,
        ECOLOGICAL_ANALYSIS,
        BODY_CONTROL,
        BIOLOGICAL_ACTUATION,
        WIRELESS_ACTIVATION,
        PAYLOAD_DELIVERY,
        DEVICE_FIRMWARE_MODIFICATION,
        UNVERIFIED_SYSTEM_MODIFICATION
    }

    public enum Decision {
        ALLOW_ADVISORY_ONLY,
        DENY
    }

    public record Request(
        RequestedCapability capability,
        String purpose,
        boolean hostApproved,
        boolean externalActionRequested
    ) {
        public Request {
            Objects.requireNonNull(capability, "capability must not be null");
            Objects.requireNonNull(purpose, "purpose must not be null");

            if (purpose.isBlank()) {
                throw new IllegalArgumentException("purpose must not be blank");
            }
        }
    }

    public record Evaluation(
        Decision decision,
        String rationale,
        boolean requiresHumanReview
    ) {}

    private static final Set<RequestedCapability> ALLOWED = EnumSet.of(
        RequestedCapability.DOCUMENTATION,
        RequestedCapability.DATA_VALIDATION,
        RequestedCapability.FORMAL_VERIFICATION,
        RequestedCapability.OFFLINE_SIMULATION,
        RequestedCapability.ENVIRONMENTAL_ROUTE_PLANNING,
        RequestedCapability.ECOLOGICAL_ANALYSIS
    );

    private static final Set<RequestedCapability> PROHIBITED = EnumSet.of(
        RequestedCapability.BODY_CONTROL,
        RequestedCapability.BIOLOGICAL_ACTUATION,
        RequestedCapability.WIRELESS_ACTIVATION,
        RequestedCapability.PAYLOAD_DELIVERY,
        RequestedCapability.DEVICE_FIRMWARE_MODIFICATION,
        RequestedCapability.UNVERIFIED_SYSTEM_MODIFICATION
    );

    private NonActuatingResearchGate() {}

    public static Evaluation evaluate(Request request) {
        Objects.requireNonNull(request, "request must not be null");

        if (request.externalActionRequested()) {
            return new Evaluation(
                Decision.DENY,
                "External action is outside the advisory-only research boundary.",
                true
            );
        }

        if (PROHIBITED.contains(request.capability())) {
            return new Evaluation(
                Decision.DENY,
                "The requested capability could control, modify, activate, or physically affect a body, device, or environment.",
                true
            );
        }

        if (!request.hostApproved()) {
            return new Evaluation(
                Decision.DENY,
                "Host approval is required for handling private research material.",
                true
            );
        }

        if (ALLOWED.contains(request.capability())) {
            return new Evaluation(
                Decision.ALLOW_ADVISORY_ONLY,
                "Permitted as a non-actuating research, documentation, validation, simulation, or planning activity.",
                false
            );
        }

        return new Evaluation(
            Decision.DENY,
            "The requested capability is not in the approved advisory-only capability set.",
            true
        );
    }
}
