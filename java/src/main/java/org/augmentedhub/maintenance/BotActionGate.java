package org.augmentedhub.maintenance;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;

public final class BotActionGate {
    private static final Duration EMERGENCY_REVIEW_WINDOW = Duration.ofSeconds(60);

    private BotActionGate() {
    }

    public enum ActionClass {
        ROUTINE_INSPECTION,
        PREVENTIVE_MAINTENANCE,
        CORRECTIVE_ACTION,
        EMERGENCY_INTERVENTION,
        UNKNOWN
    }

    public enum ReviewStatus {
        NOT_REQUIRED,
        PENDING_REVIEW,
        APPROVED,
        REJECTED,
        EXPIRED
    }

    public record ProposedAction(
            String proposalId,
            String actionType,
            Instant proposedAt,
            ReviewStatus reviewStatus,
            Optional<Instant> reviewedAt,
            boolean imminentSafetyOrEcologicalHarm
    ) {
        public ProposedAction {
            Objects.requireNonNull(proposalId, "proposalId");
            Objects.requireNonNull(actionType, "actionType");
            Objects.requireNonNull(proposedAt, "proposedAt");
            Objects.requireNonNull(reviewStatus, "reviewStatus");
            Objects.requireNonNull(reviewedAt, "reviewedAt");

            if (proposalId.isBlank()) {
                throw new IllegalArgumentException("proposalId must not be blank.");
            }

            if (actionType.isBlank()) {
                throw new IllegalArgumentException("actionType must not be blank.");
            }
        }
    }

    public record GateDecision(
            ActionClass actionClass,
            boolean executable,
            boolean requiresHumanReview,
            String reasonCode
    ) {
    }

    public static ActionClass classify(String actionType) {
        Objects.requireNonNull(actionType, "actionType");

        return switch (actionType.trim().toLowerCase(Locale.ROOT)) {
            case "routine_inspection" -> ActionClass.ROUTINE_INSPECTION;
            case "preventive_maintenance" -> ActionClass.PREVENTIVE_MAINTENANCE;
            case "corrective_action" -> ActionClass.CORRECTIVE_ACTION;
            case "emergency_intervention" -> ActionClass.EMERGENCY_INTERVENTION;
            default -> ActionClass.UNKNOWN;
        };
    }

    public static GateDecision authorize(ProposedAction action, Instant now) {
        Objects.requireNonNull(action, "action");
        Objects.requireNonNull(now, "now");

        ActionClass actionClass = classify(action.actionType());

        return switch (actionClass) {
            case ROUTINE_INSPECTION -> new GateDecision(
                    actionClass,
                    true,
                    false,
                    "ROUTINE_INSPECTION_ALLOWED"
            );

            case PREVENTIVE_MAINTENANCE -> new GateDecision(
                    actionClass,
                    true,
                    false,
                    "PREVENTIVE_MAINTENANCE_ALLOWED"
            );

            case CORRECTIVE_ACTION -> authorizeCorrectiveAction(action, actionClass);

            case EMERGENCY_INTERVENTION -> authorizeEmergencyAction(
                    action,
                    actionClass,
                    now
            );

            case UNKNOWN -> new GateDecision(
                    actionClass,
                    false,
                    true,
                    "UNKNOWN_ACTION_TYPE_FAIL_CLOSED"
            );
        };
    }

    private static GateDecision authorizeCorrectiveAction(
            ProposedAction action,
            ActionClass actionClass
    ) {
        boolean approved = action.reviewStatus() == ReviewStatus.APPROVED
                && action.reviewedAt().isPresent();

        return approved
                ? new GateDecision(
                        actionClass,
                        true,
                        true,
                        "CORRECTIVE_ACTION_HUMAN_APPROVED"
                )
                : new GateDecision(
                        actionClass,
                        false,
                        true,
                        "CORRECTIVE_ACTION_HUMAN_REVIEW_REQUIRED"
                );
    }

    private static GateDecision authorizeEmergencyAction(
            ProposedAction action,
            ActionClass actionClass,
            Instant now
    ) {
        Instant deadline = action.proposedAt().plus(EMERGENCY_REVIEW_WINDOW);

        boolean timelyHumanApproval = action.reviewStatus() == ReviewStatus.APPROVED
                && action.reviewedAt().isPresent()
                && !action.reviewedAt().get().isAfter(deadline);

        if (timelyHumanApproval) {
            return new GateDecision(
                    actionClass,
                    true,
                    true,
                    "EMERGENCY_ACTION_TIMELY_HUMAN_APPROVAL"
            );
        }

        if (action.imminentSafetyOrEcologicalHarm()) {
            return new GateDecision(
                    actionClass,
                    true,
                    true,
                    "EMERGENCY_ACTION_IMMINENT_HARM_EXCEPTION"
            );
        }

        if (now.isAfter(deadline)) {
            return new GateDecision(
                    actionClass,
                    false,
                    true,
                    "EMERGENCY_REVIEW_WINDOW_EXPIRED_FAIL_CLOSED"
            );
        }

        return new GateDecision(
                actionClass,
                false,
                true,
                "EMERGENCY_ACTION_AWAITING_HUMAN_REVIEW"
        );
    }
}
