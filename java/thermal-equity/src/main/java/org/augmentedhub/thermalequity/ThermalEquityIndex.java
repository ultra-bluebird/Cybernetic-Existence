package org.augmentedhub.thermalequity;

import java.util.List;
import java.util.Objects;

public final class ThermalEquityIndex {
    private static final double EPSILON = 1.0e-12;

    private ThermalEquityIndex() {
    }

    public record AggregateNeed(
            double heatExposure,
            double canopyDeficit,
            double accessDeficit,
            double outdoorExposure
    ) {
        public AggregateNeed {
            validateUnitInterval(heatExposure, "heatExposure");
            validateUnitInterval(canopyDeficit, "canopyDeficit");
            validateUnitInterval(accessDeficit, "accessDeficit");
            validateUnitInterval(outdoorExposure, "outdoorExposure");
        }
    }

    public record Weights(
            double heatExposure,
            double canopyDeficit,
            double accessDeficit,
            double outdoorExposure
    ) {
        public Weights {
            validateNonNegative(heatExposure, "heatExposure");
            validateNonNegative(canopyDeficit, "canopyDeficit");
            validateNonNegative(accessDeficit, "accessDeficit");
            validateNonNegative(outdoorExposure, "outdoorExposure");

            double sum = heatExposure + canopyDeficit + accessDeficit + outdoorExposure;
            if (Math.abs(sum - 1.0) > 1.0e-9) {
                throw new IllegalArgumentException("weights must sum to one");
            }
        }
    }

    public record HexCooling(
            String hexId,
            double baselineTemperatureC,
            double interventionTemperatureC,
            AggregateNeed aggregateNeed,
            boolean priorityHex,
            double minimumCoolingBenefitC,
            double heatRisk,
            double maximumHeatRisk
    ) {
        public HexCooling {
            Objects.requireNonNull(hexId, "hexId");
            Objects.requireNonNull(aggregateNeed, "aggregateNeed");

            validateFinite(baselineTemperatureC, "baselineTemperatureC");
            validateFinite(interventionTemperatureC, "interventionTemperatureC");
            validateNonNegative(minimumCoolingBenefitC, "minimumCoolingBenefitC");
            validateUnitInterval(heatRisk, "heatRisk");
            validateUnitInterval(maximumHeatRisk, "maximumHeatRisk");
        }

        public double coolingBenefitC() {
            return baselineTemperatureC - interventionTemperatureC;
        }
    }

    public record EquityResult(
            double weightedCoolingBenefit,
            boolean priorityFloorsMet,
            boolean corridorFloorsMet
    ) {
        public boolean isFeasible() {
            return priorityFloorsMet && corridorFloorsMet;
        }
    }

    public static EquityResult evaluate(
            List<HexCooling> hexes,
            Weights weights
    ) {
        Objects.requireNonNull(hexes, "hexes");
        Objects.requireNonNull(weights, "weights");

        if (hexes.isEmpty()) {
            throw new IllegalArgumentException("at least one hex is required");
        }

        double weightedCooling = 0.0;
        double totalNeed = 0.0;
        boolean priorityFloorsMet = true;
        boolean corridorFloorsMet = true;

        for (HexCooling hex : hexes) {
            double need = needWeight(hex.aggregateNeed(), weights);
            weightedCooling += need * hex.coolingBenefitC();
            totalNeed += need;

            if (hex.priorityHex()
                    && hex.coolingBenefitC() < hex.minimumCoolingBenefitC()) {
                priorityFloorsMet = false;
            }

            if (hex.heatRisk() > hex.maximumHeatRisk()) {
                corridorFloorsMet = false;
            }
        }

        return new EquityResult(
                weightedCooling / (totalNeed + EPSILON),
                priorityFloorsMet,
                corridorFloorsMet
        );
    }

    public static double needWeight(
            AggregateNeed need,
            Weights weights
    ) {
        Objects.requireNonNull(need, "need");
        Objects.requireNonNull(weights, "weights");

        return weights.heatExposure() * need.heatExposure()
                + weights.canopyDeficit() * need.canopyDeficit()
                + weights.accessDeficit() * need.accessDeficit()
                + weights.outdoorExposure() * need.outdoorExposure();
    }

    private static void validateFinite(double value, String field) {
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException(field + " must be finite");
        }
    }

    private static void validateNonNegative(double value, String field) {
        validateFinite(value, field);
        if (value < 0.0) {
            throw new IllegalArgumentException(field + " must be non-negative");
        }
    }

    private static void validateUnitInterval(double value, String field) {
        validateFinite(value, field);
        if (value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(field + " must be within [0, 1]");
        }
    }
}
