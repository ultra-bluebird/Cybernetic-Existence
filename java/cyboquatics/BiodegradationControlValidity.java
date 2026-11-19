package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class BiodegradationControlValidity {
    private BiodegradationControlValidity() {
    }

    public enum ResponseChannel {
        OXYGEN_DEMAND,
        CARBON_DIOXIDE_EVOLUTION
    }

    public enum Decision {
        CONTROL_VALIDITY_REVIEW_READY,
        INSUFFICIENT_EVIDENCE,
        REJECTED_INPUT
    }

    public record EvidenceInput(
        String methodName,
        String methodVersion,
        double durationDays,
        double minimumDurationDays,
        int replicateCount,
        int minimumReplicateCount,
        double replicateSpread,
        double maximumReplicateSpread,
        boolean blankOrNegativeControlValid,
        boolean positiveControlValid,
        ResponseChannel responseChannel,
        double oxygenDemandValue,
        double carbonDioxideEvolutionValue,
        boolean temperatureDeclared,
        boolean testMediumDeclared,
        boolean inoculumOrCompostSourceDeclared,
        boolean unitsDeclared,
        boolean calibrationCurrent,
        boolean chainOfCustodyComplete
    ) {
    }

    public record Result(
        Decision decision,
        List<String> reasons
    ) {
    }

    public static Result evaluate(EvidenceInput input) {
        if (input == null ||
            blank(input.methodName()) ||
            blank(input.methodVersion()) ||
            input.responseChannel() == null ||
            !finiteNonNegative(input.durationDays()) ||
            !finitePositive(input.minimumDurationDays()) ||
            input.replicateCount() < 1 ||
            input.minimumReplicateCount() < 1 ||
            !unit(input.replicateSpread()) ||
            !unit(input.maximumReplicateSpread())) {
            return new Result(
                Decision.REJECTED_INPUT,
                List.of("Method, duration, replicate, or response-channel input is invalid.")
            );
        }

        List<String> reasons = new ArrayList<>();
        if (input.durationDays() < input.minimumDurationDays()) {
            reasons.add("Test duration is below the configured method minimum.");
        }
        if (input.replicateCount() < input.minimumReplicateCount()) {
            reasons.add("Replicate count is below the configured minimum.");
        }
        if (!input.blankOrNegativeControlValid()) {
            reasons.add("Blank or negative control is invalid.");
        }
        if (!input.positiveControlValid()) {
            reasons.add("Positive or reference control is invalid.");
        }
        if (input.replicateSpread() > input.maximumReplicateSpread()) {
            reasons.add("Replicate spread exceeds the configured maximum.");
        }
        if (input.responseChannel() == ResponseChannel.OXYGEN_DEMAND &&
            !finiteNonNegative(input.oxygenDemandValue())) {
            reasons.add("Oxygen-demand response is missing or invalid.");
        }
        if (input.responseChannel() == ResponseChannel.CARBON_DIOXIDE_EVOLUTION &&
            !finiteNonNegative(input.carbonDioxideEvolutionValue())) {
            reasons.add("Carbon-dioxide evolution response is missing or invalid.");
        }
        if (!input.temperatureDeclared()) reasons.add("Temperature is not declared.");
        if (!input.testMediumDeclared()) reasons.add("Test medium is not declared.");
        if (!input.inoculumOrCompostSourceDeclared()) reasons.add("Inoculum or compost source is not declared.");
        if (!input.unitsDeclared()) reasons.add("Measurement units are not declared.");
        if (!input.calibrationCurrent()) reasons.add("Calibration is absent or stale.");
        if (!input.chainOfCustodyComplete()) reasons.add("Chain of custody is incomplete.");

        if (!reasons.isEmpty()) {
            return new Result(Decision.INSUFFICIENT_EVIDENCE, List.copyOf(reasons));
        }

        return new Result(
            Decision.CONTROL_VALIDITY_REVIEW_READY,
            List.of(
                "Control and metadata conditions are present for scientific review.",
                "This is not a biodegradability, safety, release, or compliance determination."
            )
        );
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
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
}
