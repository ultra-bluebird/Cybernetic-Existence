package cyboquatics;

import java.util.ArrayList;
import java.util.List;

public final class DoorSensorAlignmentAlert {
    private DoorSensorAlignmentAlert() {
    }

    public enum Decision {
        WITHIN_CONFIGURED_TIMING_BAND,
        ALIGNMENT_ALERT,
        REJECTED_INPUT
    }

    public record SensorInput(
        double expectedCrossingDurationS,
        double observedCrossingDurationS,
        double allowedDurationDeviationS,
        boolean sensorHealthFlag,
        int inconsistentSampleCount,
        int inconsistencyCountThreshold
    ) {
    }

    public record Result(
        Decision decision,
        double timingResidual,
        boolean physicalDoorControlAuthorized,
        List<String> reasons
    ) {
    }

    public static Result evaluate(SensorInput input) {
        if (input == null ||
            !finitePositive(input.expectedCrossingDurationS()) ||
            !finiteNonNegative(input.observedCrossingDurationS()) ||
            !finitePositive(input.allowedDurationDeviationS()) ||
            input.inconsistentSampleCount() < 0 ||
            input.inconsistencyCountThreshold() < 1) {
            return new Result(
                Decision.REJECTED_INPUT,
                0.0,
                false,
                List.of("Timing evidence is missing, non-finite, negative, or structurally invalid.")
            );
        }

        double residual = Math.abs(
            input.observedCrossingDurationS() - input.expectedCrossingDurationS()
        ) / input.allowedDurationDeviationS();

        List<String> reasons = new ArrayList<>();
        if (residual > 1.0) {
            reasons.add("Observed crossing duration is outside the configured timing band.");
        }
        if (!input.sensorHealthFlag()) {
            reasons.add("Sensor health flag is not present.");
        }
        if (input.inconsistentSampleCount() >= input.inconsistencyCountThreshold()) {
            reasons.add("Repeated crossing samples are inconsistent.");
        }

        if (!reasons.isEmpty()) {
            return new Result(Decision.ALIGNMENT_ALERT, residual, false, List.copyOf(reasons));
        }

        return new Result(
            Decision.WITHIN_CONFIGURED_TIMING_BAND,
            residual,
            false,
            List.of("Timing is within the configured band. This component does not control the door.")
        );
    }

    private static boolean finitePositive(double value) {
        return Double.isFinite(value) && value > 0.0;
    }

    private static boolean finiteNonNegative(double value) {
        return Double.isFinite(value) && value >= 0.0;
    }
}
