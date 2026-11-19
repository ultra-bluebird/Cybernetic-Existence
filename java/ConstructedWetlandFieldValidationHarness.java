package org.augmentedhub.cyboquatic;

import java.util.List;

public final class ConstructedWetlandFieldValidationHarness {
    public record WetlandObservation(
        String wetlandCellId,
        double vegetationCoverFraction,
        double openWaterFraction,
        double emergentVegetationFraction,
        double hydraulicLoadingMPerDay,
        double hydraulicRetentionTimeDays,
        double waterDepthM,
        boolean geometryAccepted,
        boolean vegetationMethodAccepted,
        boolean hydraulicsMethodAccepted,
        boolean pfASInfluentEvidenceAccepted,
        boolean pfASEffluentEvidenceAccepted,
        boolean pfASAnalyticalMethodAccepted,
        boolean chainOfCustodyPresent
    ) {
    }

    public record ValidationResult(
        boolean geometryAndHydraulicsAccepted,
        boolean pfASMassBalanceReady,
        String reason
    ) {
    }

    private ConstructedWetlandFieldValidationHarness() {
    }

    public static ValidationResult validate(final WetlandObservation observation) {
        if (observation == null) {
            return new ValidationResult(false, false, "wetland observation is required");
        }

        if (!validUnitFraction(observation.vegetationCoverFraction())
            || !validUnitFraction(observation.openWaterFraction())
            || !validUnitFraction(observation.emergentVegetationFraction())) {
            return new ValidationResult(
                false,
                false,
                "cover fractions must be finite values within [0, 1]"
            );
        }

        if (observation.openWaterFraction() + observation.emergentVegetationFraction() > 1.0d) {
            return new ValidationResult(
                false,
                false,
                "open-water and emergent-vegetation fractions exceed available cell area"
            );
        }

        if (!finiteNonNegative(observation.hydraulicLoadingMPerDay())
            || !finitePositive(observation.hydraulicRetentionTimeDays())
            || !finiteNonNegative(observation.waterDepthM())) {
            return new ValidationResult(
                false,
                false,
                "hydraulic loading, retention time, or depth violates basic invariants"
            );
        }

        final boolean geometryAndHydraulicsAccepted =
            observation.geometryAccepted()
                && observation.vegetationMethodAccepted()
                && observation.hydraulicsMethodAccepted();

        if (!geometryAndHydraulicsAccepted) {
            return new ValidationResult(
                false,
                false,
                "geometry, vegetation method, or hydraulics method remains unaccepted"
            );
        }

        final boolean pfASMassBalanceReady =
            observation.pfASInfluentEvidenceAccepted()
                && observation.pfASEffluentEvidenceAccepted()
                && observation.pfASAnalyticalMethodAccepted()
                && observation.chainOfCustodyPresent();

        return new ValidationResult(
            true,
            pfASMassBalanceReady,
            pfASMassBalanceReady
                ? "geometry/hydraulics accepted; paired PFAS mass-balance review may proceed"
                : "geometry/hydraulics accepted; PFAS-specific field evidence remains incomplete"
        );
    }

    private static boolean validUnitFraction(final double value) {
        return Double.isFinite(value) && value >= 0.0d && value <= 1.0d;
    }

    private static boolean finiteNonNegative(final double value) {
        return Double.isFinite(value) && value >= 0.0d;
    }

    private static boolean finitePositive(final double value) {
        return Double.isFinite(value) && value > 0.0d;
    }
}
