package cyboquatics;

import java.util.List;

public final class GatheringHubEquity {
    private GatheringHubEquity() {
    }

    public record BlockAccess(
        String aggregateAreaId,
        double populationWeight,
        double coverageRatio,
        double transitTimeMinutes,
        double timeThresholdMinutes,
        double dataQuality
    ) {
    }

    public record EquityResult(
        double cityEquityScore,
        double minimumBlockAccessScore,
        double maximumBlockAccessScore,
        double accessGap,
        double weightedDataQuality
    ) {
    }

    public static EquityResult evaluate(List<BlockAccess> blocks) {
        if (blocks == null || blocks.isEmpty()) {
            throw new IllegalArgumentException("At least one aggregate area is required.");
        }

        double weightedScoreSum = 0.0;
        double totalWeight = 0.0;
        double weightedQualitySum = 0.0;
        double minimumScore = Double.POSITIVE_INFINITY;
        double maximumScore = Double.NEGATIVE_INFINITY;

        for (BlockAccess block : blocks) {
            validate(block);

            double travelAccess = clamp01(
                1.0 - block.transitTimeMinutes() / block.timeThresholdMinutes()
            );
            double blockAccessScore = block.coverageRatio() * travelAccess;

            weightedScoreSum += block.populationWeight() * blockAccessScore;
            weightedQualitySum += block.populationWeight() * block.dataQuality();
            totalWeight += block.populationWeight();
            minimumScore = Math.min(minimumScore, blockAccessScore);
            maximumScore = Math.max(maximumScore, blockAccessScore);
        }

        return new EquityResult(
            weightedScoreSum / totalWeight,
            minimumScore,
            maximumScore,
            maximumScore - minimumScore,
            weightedQualitySum / totalWeight
        );
    }

    private static void validate(BlockAccess block) {
        if (block == null || block.aggregateAreaId() == null || block.aggregateAreaId().isBlank()) {
            throw new IllegalArgumentException("An aggregate-area identifier is required.");
        }
        if (!finite(block.populationWeight()) || block.populationWeight() <= 0.0) {
            throw new IllegalArgumentException("Population weight must be finite and positive.");
        }
        if (!unit(block.coverageRatio()) || !unit(block.dataQuality())) {
            throw new IllegalArgumentException("Coverage ratio and data quality must be in 0..1.");
        }
        if (!finite(block.transitTimeMinutes()) || block.transitTimeMinutes() < 0.0) {
            throw new IllegalArgumentException("Transit time must be finite and non-negative.");
        }
        if (!finite(block.timeThresholdMinutes()) || block.timeThresholdMinutes() <= 0.0) {
            throw new IllegalArgumentException("Time threshold must be finite and positive.");
        }
    }

    private static boolean finite(double value) {
        return Double.isFinite(value);
    }

    private static boolean unit(double value) {
        return finite(value) && value >= 0.0 && value <= 1.0;
    }

    private static double clamp01(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
