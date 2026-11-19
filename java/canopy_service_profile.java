package org.augmentedhub.canopy;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

public final class CanopyServiceProfile {
    public record Inputs(
            double canopyAreaM2,
            double carbonStorageKg,
            double annualCarbonSequestrationKg,
            double annualRunoffAvoidedM3,
            double annualPollutionRemovalG,
            double shadeAreaM2,
            double heatMitigationIndex,
            double habitatSupportIndex
    ) {}

    public record ServiceProfile(
            Map<String, Double> nonMarketBenefits,
            double planningPriority,
            boolean suitableForPublicAggregateRelease
    ) {}

    public ServiceProfile calculate(
            Inputs inputs,
            Map<String, Double> participatoryWeights,
            double minimumAggregateCanopyAreaM2) {

        Objects.requireNonNull(inputs, "inputs");
        Objects.requireNonNull(participatoryWeights, "participatoryWeights");

        requireNonNegative(inputs.canopyAreaM2(), "canopyAreaM2");
        requireNonNegative(inputs.carbonStorageKg(), "carbonStorageKg");
        requireNonNegative(inputs.annualCarbonSequestrationKg(), "annualCarbonSequestrationKg");
        requireNonNegative(inputs.annualRunoffAvoidedM3(), "annualRunoffAvoidedM3");
        requireNonNegative(inputs.annualPollutionRemovalG(), "annualPollutionRemovalG");
        requireNonNegative(inputs.shadeAreaM2(), "shadeAreaM2");
        validateUnitInterval(inputs.heatMitigationIndex(), "heatMitigationIndex");
        validateUnitInterval(inputs.habitatSupportIndex(), "habitatSupportIndex");
        requireNonNegative(minimumAggregateCanopyAreaM2, "minimumAggregateCanopyAreaM2");

        final Map<String, Double> benefits = new LinkedHashMap<>();
        benefits.put("canopy_area_m2", inputs.canopyAreaM2());
        benefits.put("carbon_storage_kg", inputs.carbonStorageKg());
        benefits.put("annual_carbon_sequestration_kg", inputs.annualCarbonSequestrationKg());
        benefits.put("annual_runoff_avoided_m3", inputs.annualRunoffAvoidedM3());
        benefits.put("annual_pollution_removal_g", inputs.annualPollutionRemovalG());
        benefits.put("shade_area_m2", inputs.shadeAreaM2());
        benefits.put("heat_mitigation_index", inputs.heatMitigationIndex());
        benefits.put("habitat_support_index", inputs.habitatSupportIndex());

        double priority = 0.0;
        for (Map.Entry<String, Double> weight : participatoryWeights.entrySet()) {
            final Double benefit = benefits.get(weight.getKey());
            if (benefit == null) {
                throw new IllegalArgumentException("Unknown service key: " + weight.getKey());
            }
            requireNonNegative(weight.getValue(), "participatory weight");
            priority += weight.getValue() * benefit;
        }

        return new ServiceProfile(
                Map.copyOf(benefits),
                priority,
                inputs.canopyAreaM2() >= minimumAggregateCanopyAreaM2);
    }

    private static void requireNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }

    private static void validateUnitInterval(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(name + " must be within [0, 1].");
        }
    }
}
