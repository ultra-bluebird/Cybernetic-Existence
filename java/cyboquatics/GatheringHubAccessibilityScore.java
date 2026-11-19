package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class GatheringHubAccessibilityScore {
    private GatheringHubAccessibilityScore() {
    }

    public enum Decision {
        ACCESSIBILITY_SCORE_AVAILABLE,
        ACCESSIBILITY_REVIEW_REQUIRED,
        REJECTED_INPUT
    }

    public record HubInput(
        String hubId,
        double entranceClearWidthM,
        double requiredEntranceClearWidthM,
        double rampSlopeRatio,
        double shadeScore,
        double seatingScore,
        double transitProximityScore,
        double routeContinuityScore,
        double informationAccessScore,
        boolean individualTrackingPresent,
        boolean personalDataPresent
    ) {
    }

    public record Result(
        Decision decision,
        double score,
        List<String> reasons
    ) {
    }

    public static Result evaluate(HubInput input) {
        if (input == null ||
            input.hubId() == null ||
            input.hubId().isBlank() ||
            !finitePositive(input.entranceClearWidthM()) ||
            !finitePositive(input.requiredEntranceClearWidthM()) ||
            !finiteNonNegative(input.rampSlopeRatio()) ||
            !unit(input.shadeScore()) ||
            !unit(input.seatingScore()) ||
            !unit(input.transitProximityScore()) ||
            !unit(input.routeContinuityScore()) ||
            !unit(input.informationAccessScore())) {
            return new Result(
                Decision.REJECTED_INPUT,
                0.0,
                List.of("Hub accessibility inputs are incomplete or outside configured bounds.")
            );
        }

        double entranceScore = clamp01(
            input.entranceClearWidthM() / input.requiredEntranceClearWidthM()
        );
        double rampScore = input.rampSlopeRatio() <= (1.0 / 12.0) ? 1.0 : 0.0;
        double score =
            0.25 * entranceScore +
            0.15 * rampScore +
            0.15 * input.shadeScore() +
            0.15 * input.seatingScore() +
            0.15 * input.transitProximityScore() +
            0.10 * input.routeContinuityScore() +
            0.05 * input.informationAccessScore();

        List<String> reasons = new ArrayList<>();
        if (input.individualTrackingPresent()) reasons.add("Individual tracking is prohibited.");
        if (input.personalDataPresent()) reasons.add("Personal data is prohibited.");
        if (entranceScore < 1.0) reasons.add("Entrance clear width is below the configured requirement.");
        if (rampScore == 0.0) reasons.add("Ramp slope exceeds 1:12.");
        if (input.routeContinuityScore() < 1.0) reasons.add("Accessible-route continuity requires review.");

        if (!reasons.isEmpty()) {
            return new Result(Decision.ACCESSIBILITY_REVIEW_REQUIRED, score, List.copyOf(reasons));
        }

        return new Result(
            Decision.ACCESSIBILITY_SCORE_AVAILABLE,
            score,
            List.of("Facility-level score only; no individual tracking is used.")
        );
    }

    private static boolean finitePositive(double value) {
        return Double.isFinite(value) && value > 0.0;
    }

    private static boolean finiteNonNegative(double value) {
        return Double.isFinite(value) && value >= 0.0;
    }

    private static boolean unit(double value) {
        return Double.isFinite(value) && value >= 0.0 && value <= 1.0;
    }

    private static double clamp01(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
