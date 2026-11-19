package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class ExternalActionApprovalGate {
    private ExternalActionApprovalGate() {
    }

    public enum Decision {
        HUMAN_APPROVAL_REQUIRED,
        APPROVAL_PACKET_COMPLETE,
        REJECTED_INPUT
    }

    public record ApprovalPacket(
        String actionId,
        String targetValveId,
        String requestedChange,
        String purpose,
        String qualifiedHumanApproverId,
        boolean qualificationCurrent,
        boolean exactActionApproved,
        String approvedAtUtc,
        String expiresAtUtc,
        boolean riskReviewComplete,
        boolean safetyInterlocksVerified,
        boolean siteProcedureVerified,
        boolean accessibleExplanationProvided,
        boolean auditRecordPrepared
    ) {
    }

    public record GateResult(
        Decision decision,
        List<String> reasons,
        boolean physicalActuationAuthorized
    ) {
    }

    public static GateResult evaluate(ApprovalPacket packet) {
        if (packet == null ||
            blank(packet.actionId()) ||
            blank(packet.targetValveId()) ||
            blank(packet.requestedChange()) ||
            blank(packet.purpose()) ||
            blank(packet.approvedAtUtc()) ||
            blank(packet.expiresAtUtc())) {
            return new GateResult(
                Decision.REJECTED_INPUT,
                List.of("The proposal lacks required action, target, purpose, or timestamp fields."),
                false
            );
        }

        List<String> reasons = new ArrayList<>();
        if (blank(packet.qualifiedHumanApproverId())) reasons.add("A qualified human approver is required.");
        if (!packet.qualificationCurrent()) reasons.add("The qualification record is absent or expired.");
        if (!packet.exactActionApproved()) reasons.add("The exact valve target and requested change lack separate approval.");
        if (!packet.riskReviewComplete()) reasons.add("Risk review is incomplete.");
        if (!packet.safetyInterlocksVerified()) reasons.add("Safety interlocks are not verified.");
        if (!packet.siteProcedureVerified()) reasons.add("Site procedure verification is incomplete.");
        if (!packet.accessibleExplanationProvided()) reasons.add("An accessible explanation is missing.");
        if (!packet.auditRecordPrepared()) reasons.add("The audit record is missing.");

        if (!reasons.isEmpty()) {
            return new GateResult(Decision.HUMAN_APPROVAL_REQUIRED, List.copyOf(reasons), false);
        }

        return new GateResult(
            Decision.APPROVAL_PACKET_COMPLETE,
            List.of(
                "The approval packet is complete for qualified human review.",
                "This component never authorizes, transmits, or executes physical valve actuation."
            ),
            false
        );
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
