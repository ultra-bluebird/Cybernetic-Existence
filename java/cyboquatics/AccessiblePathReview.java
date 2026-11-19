package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class AccessiblePathReview {
    private AccessiblePathReview() {
    }

    public record PathInput(
        double physicalWidthM,
        double expansionGapM,
        double obstructionBufferM,
        double mobilityVarianceBufferM,
        double requiredClearWidthM,
        double runningSlopeRatio,
        boolean heatResilienceInspectionCurrent,
        boolean debrisInspectionCurrent
    ) {
    }

    public record PathResult(
        boolean reviewRequired,
        double effectiveWidthM,
        List<String> reasons
    ) {
    }

    public static PathResult evaluate(PathInput input) {
        validateFiniteNonNegative(input.physicalWidthM(), "physicalWidthM");
        validateFiniteNonNegative(input.expansionGapM(), "expansionGapM");
        validateFiniteNonNegative(input.obstructionBufferM(), "obstructionBufferM");
        validateFiniteNonNegative(input.mobilityVarianceBufferM(), "mobilityVarianceBufferM");
        validateFinitePositive(input.requiredClearWidthM(), "requiredClearWidthM");
        validateFiniteNonNegative(input.runningSlopeRatio(), "runningSlopeRatio");

        double effectiveWidthM = input.physicalWidthM()
            - input.expansionGapM()
            - input.obstructionBufferM()
            - input.mobilityVarianceBufferM();

        List<String> reasons = new ArrayList<>();
        if (effectiveWidthM < input.requiredClearWidthM()) {
            reasons.add("Effective width is below the configured required clear width.");
        }
        if (input.runningSlopeRatio() > 1.0 / 12.0) {
            reasons.add("Running slope is steeper than 1:12.");
        }
        if (!input.heatResilienceInspectionCurrent()) {
            reasons.add("Heat-resilience inspection is missing or expired.");
        }
        if (!input.debrisInspectionCurrent()) {
            reasons.add("Debris inspection is missing or expired.");
        }

        return new PathResult(!reasons.isEmpty(), effectiveWidthM, List.copyOf(reasons));
    }

    private static void validateFiniteNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }

    private static void validateFinitePositive(double value, String name) {
        if (!Double.isFinite(value) || value <= 0.0) {
            throw new IllegalArgumentException(name + " must be finite and positive.");
        }
    }
}
