package org.augmentedhub.albedo;

import java.util.List;
import java.util.Objects;

public final class UrbanAlbedoEnergyBalance {
    public record SurfaceScenario(
            String materialReference,
            double albedo,
            double emissivity,
            double surfaceTemperatureKelvin,
            double incomingShortwaveRadiationWm2,
            double glareRisk,
            double ecologicalConstraintCost,
            double maintenanceImpact,
            double communityAestheticCost
    ) {
        public SurfaceScenario {
            Objects.requireNonNull(materialReference, "materialReference");

            requireRange(albedo, 0.0, 1.0, "albedo");
            requireRange(emissivity, 0.0, 1.0, "emissivity");
            requireNonNegative(surfaceTemperatureKelvin, "surfaceTemperatureKelvin");
            requireNonNegative(incomingShortwaveRadiationWm2, "incomingShortwaveRadiationWm2");
            requireRange(glareRisk, 0.0, 1.0, "glareRisk");
            requireRange(ecologicalConstraintCost, 0.0, 1.0, "ecologicalConstraintCost");
            requireRange(maintenanceImpact, 0.0, 1.0, "maintenanceImpact");
            requireRange(communityAestheticCost, 0.0, 1.0, "communityAestheticCost");
        }
    }

    public record Weights(
            double coolingBenefit,
            double glare,
            double ecologicalConstraint,
            double maintenance,
            double communityAesthetics
    ) {
        public Weights {
            requireNonNegative(coolingBenefit, "coolingBenefit");
            requireNonNegative(glare, "glare");
            requireNonNegative(ecologicalConstraint, "ecologicalConstraint");
            requireNonNegative(maintenance, "maintenance");
            requireNonNegative(communityAesthetics, "communityAesthetics");
        }
    }

    public record Evaluation(
            String materialReference,
            double netRadiativeBalanceWm2,
            double normalizedCoolingBenefit,
            double multiObjectiveScore,
            boolean eligibleForReview
    ) {}

    private static final double STEFAN_BOLTZMANN = 5.670374419e-8;

    public Evaluation evaluate(
            SurfaceScenario scenario,
            double baselineNetRadiativeBalanceWm2,
            Weights weights,
            double maximumGlareRisk,
            double maximumEcologicalConstraintCost) {

        Objects.requireNonNull(scenario, "scenario");
        Objects.requireNonNull(weights, "weights");

        requireFinite(baselineNetRadiativeBalanceWm2, "baselineNetRadiativeBalanceWm2");
        requireRange(maximumGlareRisk, 0.0, 1.0, "maximumGlareRisk");
        requireRange(
                maximumEcologicalConstraintCost,
                0.0,
                1.0,
                "maximumEcologicalConstraintCost");

        final double netBalance =
                scenario.incomingShortwaveRadiationWm2() * (1.0 - scenario.albedo())
                - scenario.emissivity() * STEFAN_BOLTZMANN
                * Math.pow(scenario.surfaceTemperatureKelvin(), 4.0);

        final double coolingBenefit =
                Math.max(0.0, baselineNetRadiativeBalanceWm2 - netBalance);

        final double normalizedCooling = coolingBenefit
                / Math.max(1.0, Math.abs(baselineNetRadiativeBalanceWm2));

        final double score =
                weights.coolingBenefit() * normalizedCooling
                - weights.glare() * scenario.glareRisk()
                - weights.ecologicalConstraint() * scenario.ecologicalConstraintCost()
                - weights.maintenance() * scenario.maintenanceImpact()
                - weights.communityAesthetics() * scenario.communityAestheticCost();

        final boolean eligible =
                scenario.glareRisk() <= maximumGlareRisk
                && scenario.ecologicalConstraintCost() <= maximumEcologicalConstraintCost;

        return new Evaluation(
                scenario.materialReference(),
                netBalance,
                normalizedCooling,
                score,
                eligible);
    }

    public Evaluation selectHighestEligible(
            List<SurfaceScenario> scenarios,
            double baselineNetRadiativeBalanceWm2,
            Weights weights,
            double maximumGlareRisk,
            double maximumEcologicalConstraintCost) {

        Objects.requireNonNull(scenarios, "scenarios");

        return scenarios.stream()
                .map(scenario -> evaluate(
                        scenario,
                        baselineNetRadiativeBalanceWm2,
                        weights,
                        maximumGlareRisk,
                        maximumEcologicalConstraintCost))
                .filter(Evaluation::eligibleForReview)
                .max(java.util.Comparator.comparingDouble(Evaluation::multiObjectiveScore))
                .orElseThrow(() -> new IllegalStateException(
                        "No scenario satisfies the glare and ecological eligibility limits."));
    }

    private static void requireNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }

    private static void requireRange(double value, double minimum, double maximum, String name) {
        if (!Double.isFinite(value) || value < minimum || value > maximum) {
            throw new IllegalArgumentException(name + " is outside its accepted range.");
        }
    }

    private static void requireFinite(double value, String name) {
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException(name + " must be finite.");
        }
    }
}
