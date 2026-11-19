package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class InclusiveDoorTimingReview {
    private InclusiveDoorTimingReview() {
    }

    public enum Decision {
        DOOR_TIMING_WITHIN_REVIEW_BOUNDS,
        DOOR_TIMING_REVIEW_REQUIRED,
        REJECTED_INPUT
    }

    public record Input(
        double configuredHoldOpenS,
        double configuredMinimumOpenS,
        double approvedAccessibilityProfileMaxCrossingS,
        double safetyBufferS,
        boolean sensorHealthFlag,
        boolean profileReviewCurrent,
        boolean accessibleMoreTimeRequestAvailable,
        boolean individualTrackingPresent
    ) {
    }

    public record Result(
        Decision decision,
        double recommendedHoldOpenS,
        boolean physicalDoorControlAuthorized,
        List<String> reasons
    ) {
    }

    public static Result evaluate(Input input) {
        if (input == null ||
            !finiteNonNegative(input.configuredHoldOpenS()) ||
            !finiteNonNegative(input.configuredMinimumOpenS()) ||
            !finiteNonNegative(input.approvedAccessibilityProfileMaxCrossingS()) ||
            !finiteNonNegative(input.safetyBufferS())) {
            return new Result(
                Decision.REJECTED_INPUT,
                0.0,
                false,
                List.of("Door timing configuration is missing, non-finite, or negative.")
            );
        }

        double recommended = Math.max(
            input.configuredMinimumOpenS(),
            input.approvedAccessibilityProfileMaxCrossingS() + input.safetyBufferS()
        );

        List<String> reasons = new ArrayList<>();
        if (input.configuredHoldOpenS() < recommended) {
            reasons.add("Configured hold-open time is below the accessibility review recommendation.");
        }
        if (!input.sensorHealthFlag()) {
            reasons.add("Door safety sensor health is not verified.");
        }
        if (!input.profileReviewCurrent()) {
            reasons.add("Accessibility timing profile review is expired.");
        }
        if (!input.accessibleMoreTimeRequestAvailable()) {
            reasons.add("No accessible request-for-more-time route is available.");
        }
        if (input.individualTrackingPresent()) {
            reasons.add("Individual tracking is prohibited in door timing review.");
        }

        if (!reasons.isEmpty()) {
            return new Result(
                Decision.DOOR_TIMING_REVIEW_REQUIRED,
                recommended,
                false,
                List.copyOf(reasons)
            );
        }

        return new Result(
            Decision.DOOR_TIMING_WITHIN_REVIEW_BOUNDS,
            recommended,
            false,
            List.of("Timing meets the configured inclusive review profile. This component does not control the door.")
        );
    }

    private static boolean finiteNonNegative(double value) {
        return Double.isFinite(value) && value >= 0.0;
    }
}
