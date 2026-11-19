package org.augmentedhub.hearthline;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class LanternIntegrityEvaluator {
    public enum State {
        NORMAL,
        ELEVATED_SCRUTINY,
        RATE_LIMITED
    }

    public enum ActionType {
        ACCOUNT_ENROLLMENT,
        ACCOUNT_RECOVERY,
        MESSAGE_REQUEST,
        PROFILE_EDIT,
        EXTERNAL_LINK,
        DATA_EXPORT
    }

    public enum ReasonCode {
        ACTION_VELOCITY,
        FAILED_ASSERTION_SEQUENCE,
        RECOVERY_ATTEMPT_BURST,
        REPLAY_ANOMALY,
        EXPLICIT_REPORT_REQUIRES_REVIEW
    }

    public record SignalWindow(
            boolean webAuthnAssertionVerified,
            int actionCountInWindow,
            int failedAttemptsInWindow,
            boolean replayAnomalyDetected,
            boolean explicitReportRequiresReview
    ) {
        public SignalWindow {
            if (actionCountInWindow < 0 || failedAttemptsInWindow < 0) {
                throw new IllegalArgumentException("Counters must be non-negative");
            }
        }
    }

    public record Decision(
            State state,
            List<ReasonCode> reasonCodes,
            Instant expiresAt,
            boolean matchingUseProhibited,
            boolean publicExposureProhibited,
            boolean externalActionAuthorized
    ) {
        public Decision {
            Objects.requireNonNull(state, "state");
            reasonCodes = List.copyOf(reasonCodes);
            Objects.requireNonNull(expiresAt, "expiresAt");

            if (!matchingUseProhibited || !publicExposureProhibited) {
                throw new IllegalArgumentException(
                        "Lantern decisions must be excluded from matching and public exposure"
                );
            }

            if (externalActionAuthorized) {
                throw new IllegalArgumentException(
                        "Lantern decisions cannot authorize external actions"
                );
            }
        }
    }

    private final int elevatedVelocityThreshold;
    private final int rateLimitVelocityThreshold;
    private final int failedAttemptThreshold;
    private final ClockSource clock;

    public LanternIntegrityEvaluator(
            int elevatedVelocityThreshold,
            int rateLimitVelocityThreshold,
            int failedAttemptThreshold,
            ClockSource clock
    ) {
        if (elevatedVelocityThreshold < 1
                || rateLimitVelocityThreshold <= elevatedVelocityThreshold
                || failedAttemptThreshold < 1) {
            throw new IllegalArgumentException("Invalid Lantern thresholds");
        }

        this.elevatedVelocityThreshold = elevatedVelocityThreshold;
        this.rateLimitVelocityThreshold = rateLimitVelocityThreshold;
        this.failedAttemptThreshold = failedAttemptThreshold;
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    public Decision evaluate(ActionType actionType, SignalWindow signals) {
        Objects.requireNonNull(actionType, "actionType");
        Objects.requireNonNull(signals, "signals");

        Instant now = clock.now();

        if (signals.replayAnomalyDetected()) {
            return decision(
                    State.RATE_LIMITED,
                    List.of(ReasonCode.REPLAY_ANOMALY),
                    now.plus(Duration.ofMinutes(20))
            );
        }

        if (actionType == ActionType.ACCOUNT_RECOVERY
                && signals.failedAttemptsInWindow() >= failedAttemptThreshold) {
            return decision(
                    State.RATE_LIMITED,
                    List.of(ReasonCode.RECOVERY_ATTEMPT_BURST),
                    now.plus(Duration.ofMinutes(30))
            );
        }

        if (signals.actionCountInWindow() >= rateLimitVelocityThreshold) {
            return decision(
                    State.RATE_LIMITED,
                    List.of(ReasonCode.ACTION_VELOCITY),
                    now.plus(Duration.ofMinutes(10))
            );
        }

        if (!signals.webAuthnAssertionVerified()
                || signals.failedAttemptsInWindow() >= failedAttemptThreshold
                || signals.actionCountInWindow() >= elevatedVelocityThreshold
                || signals.explicitReportRequiresReview()) {
            return decision(
                    State.ELEVATED_SCRUTINY,
                    reasons(signals),
                    now.plus(Duration.ofMinutes(15))
            );
        }

        return decision(
                State.NORMAL,
                List.of(),
                now.plus(Duration.ofMinutes(5))
        );
    }

    private static List<ReasonCode> reasons(SignalWindow signals) {
        java.util.ArrayList<ReasonCode> reasons = new java.util.ArrayList<>();

        if (!signals.webAuthnAssertionVerified()
                || signals.failedAttemptsInWindow() > 0) {
            reasons.add(ReasonCode.FAILED_ASSERTION_SEQUENCE);
        }

        if (signals.actionCountInWindow() > 0) {
            reasons.add(ReasonCode.ACTION_VELOCITY);
        }

        if (signals.explicitReportRequiresReview()) {
            reasons.add(ReasonCode.EXPLICIT_REPORT_REQUIRES_REVIEW);
        }

        return List.copyOf(reasons);
    }

    private static Decision decision(
            State state,
            List<ReasonCode> reasons,
            Instant expiresAt
    ) {
        return new Decision(
                state,
                reasons,
                expiresAt,
                true,
                true,
                false
        );
    }

    public interface ClockSource {
        Instant now();
    }
}
