package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class BiodegradationEvidenceReview {
    private BiodegradationEvidenceReview() {
    }

    public enum Decision {
        INSUFFICIENT_EVIDENCE,
        INTERNALLY_CONSISTENT_REVIEW_REQUIRED,
        REJECTED_INPUT
    }

    public enum ResponseChannel {
        OXYGEN_DEMAND,
        CARBON_DIOXIDE_EVOLUTION
    }

    public record EvidenceRecord(
        String methodName,
        String methodVersion,
        ResponseChannel responseChannel,
        double durationDays,
        double temperatureC,
        double temperatureStabilityC,
        boolean testMediumDeclared,
        boolean inoculumOrCompostSourceDeclared,
        boolean testMaterialIdentityDeclared,
        boolean testMaterialConcentrationDeclared,
        boolean blankControlValid,
        boolean positiveControlValid,
        boolean biologicalResponseObserved,
        int replicateCount,
        double replicateRelativeDifference,
        boolean unitsDeclared,
        boolean calibrationCurrent,
        boolean chainOfCustodyComplete,
        double oxygenDemandValue,
        double carbonDioxideEvolutionValue
    ) {
    }

    public record ReviewResult(
        Decision decision,
        List<String> reasons
    ) {
    }

    public static ReviewResult evaluate(EvidenceRecord record) {
        if (record == null ||
            blank(record.methodName()) ||
            blank(record.methodVersion()) ||
            record.responseChannel() == null ||
            !finiteNonNegative(record.durationDays()) ||
            !finite(record.temperatureC()) ||
            !finiteNonNegative(record.temperatureStabilityC()) ||
            record.replicateCount() < 1 ||
            !unit(record.replicateRelativeDifference())) {
            return new ReviewResult(
                Decision.REJECTED_INPUT,
                List.of("Required evidence fields are missing, non-finite, or structurally invalid.")
            );
        }

        List<String> reasons = new ArrayList<>();
        if (!record.testMediumDeclared()) reasons.add("Test medium is not declared.");
        if (!record.inoculumOrCompostSourceDeclared()) reasons.add("Inoculum or compost source is not declared.");
        if (!record.testMaterialIdentityDeclared()) reasons.add("Test material identity is not declared.");
        if (!record.testMaterialConcentrationDeclared()) reasons.add("Test material concentration is not declared.");
        if (!record.blankControlValid()) reasons.add("Blank control is invalid.");
        if (!record.positiveControlValid()) reasons.add("Positive control is invalid.");
        if (!record.biologicalResponseObserved()) reasons.add("Biological response or inhibition observation is absent.");
        if (record.replicateCount() < 2) reasons.add("Fewer than two replicates are documented.");
        if (!record.unitsDeclared()) reasons.add("Measurement units are not declared.");
        if (!record.calibrationCurrent()) reasons.add("Instrument calibration is absent or stale.");
        if (!record.chainOfCustodyComplete()) reasons.add("Chain of custody is incomplete.");

        if (record.responseChannel() == ResponseChannel.OXYGEN_DEMAND &&
            !finiteNonNegative(record.oxygenDemandValue())) {
            reasons.add("Oxygen-demand response is missing or invalid for the declared method.");
        }

        if (record.responseChannel() == ResponseChannel.CARBON_DIOXIDE_EVOLUTION &&
            !finiteNonNegative(record.carbonDioxideEvolutionValue())) {
            reasons.add("Carbon-dioxide evolution response is missing or invalid for the declared method.");
        }

        if (!reasons.isEmpty()) {
            return new ReviewResult(Decision.INSUFFICIENT_EVIDENCE, List.copyOf(reasons));
        }

        return new ReviewResult(
            Decision.INTERNALLY_CONSISTENT_REVIEW_REQUIRED,
            List.of(
                "Required metadata and declared response channel are internally consistent.",
                "This result is not a biodegradability, safety, compliance, or release determination."
            )
        );
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }

    private static boolean finite(double value) {
        return Double.isFinite(value);
    }

    private static boolean finiteNonNegative(double value) {
        return finite(value) && value >= 0.0;
    }

    private static boolean unit(double value) {
        return finite(value) && value >= 0.0 && value <= 1.0;
    }
}
