package org.augmentedhub.cyboquatic;

import java.util.Arrays;

public final class DrainageDecayKalmanFilter {
    public record Observation(
        int componentIndex,
        double normalizedValue,
        double variance,
        long observationId
    ) {
    }

    public record FrameEstimate(
        double[] state,
        double[][] covariance,
        double residualNorm,
        long[] contributingObservationIds
    ) {
    }

    private static final int STATE_SIZE = 3;

    private DrainageDecayKalmanFilter() {
    }

    public static FrameEstimate update(
        final double[] priorState,
        final double[][] priorCovariance,
        final Observation[] observations
    ) {
        validateState(priorState, priorCovariance);

        if (observations == null || observations.length == 0) {
            throw new IllegalArgumentException("at least one observation is required");
        }

        final double[] state = Arrays.copyOf(priorState, STATE_SIZE);
        final double[][] covariance = copyMatrix(priorCovariance);
        final long[] observationIds = new long[observations.length];
        double residualSumSquares = 0.0d;

        for (int index = 0; index < observations.length; index++) {
            final Observation observation = observations[index];
            validateObservation(observation);

            final int component = observation.componentIndex();
            final double predicted = state[component];
            final double innovation = observation.normalizedValue() - predicted;
            final double innovationVariance = covariance[component][component] + observation.variance();

            if (!Double.isFinite(innovationVariance) || innovationVariance <= 0.0d) {
                throw new IllegalArgumentException("innovation variance must be finite and positive");
            }

            final double[] gain = new double[STATE_SIZE];
            for (int row = 0; row < STATE_SIZE; row++) {
                gain[row] = covariance[row][component] / innovationVariance;
            }

            for (int row = 0; row < STATE_SIZE; row++) {
                state[row] += gain[row] * innovation;
                state[row] = clampUnitInterval(state[row]);
            }

            final double[][] updatedCovariance = new double[STATE_SIZE][STATE_SIZE];
            for (int row = 0; row < STATE_SIZE; row++) {
                for (int column = 0; column < STATE_SIZE; column++) {
                    updatedCovariance[row][column] =
                        covariance[row][column]
                        - gain[row] * covariance[component][column];
                }
            }

            copyInto(updatedCovariance, covariance);
            residualSumSquares += (innovation * innovation) / innovationVariance;
            observationIds[index] = observation.observationId();
        }

        return new FrameEstimate(
            state,
            covariance,
            Math.sqrt(residualSumSquares),
            observationIds
        );
    }

    private static void validateState(
        final double[] state,
        final double[][] covariance
    ) {
        if (state == null || state.length != STATE_SIZE) {
            throw new IllegalArgumentException("state must contain BOD, TSS, and CEC components");
        }

        if (covariance == null || covariance.length != STATE_SIZE) {
            throw new IllegalArgumentException("covariance must be a 3 by 3 matrix");
        }

        for (int row = 0; row < STATE_SIZE; row++) {
            if (covariance[row] == null || covariance[row].length != STATE_SIZE) {
                throw new IllegalArgumentException("covariance must be a 3 by 3 matrix");
            }

            if (!Double.isFinite(state[row]) || state[row] < 0.0d || state[row] > 1.0d) {
                throw new IllegalArgumentException("state values must be finite and within [0, 1]");
            }

            for (int column = 0; column < STATE_SIZE; column++) {
                if (!Double.isFinite(covariance[row][column])) {
                    throw new IllegalArgumentException("covariance entries must be finite");
                }

                if (Math.abs(covariance[row][column] - covariance[column][row]) > 1.0e-9d) {
                    throw new IllegalArgumentException("covariance must be symmetric");
                }
            }

            if (covariance[row][row] <= 0.0d) {
                throw new IllegalArgumentException("covariance diagonal must be positive");
            }
        }
    }

    private static void validateObservation(final Observation observation) {
        if (observation == null) {
            throw new IllegalArgumentException("observation must not be null");
        }

        if (observation.componentIndex() < 0 || observation.componentIndex() >= STATE_SIZE) {
            throw new IllegalArgumentException("componentIndex must be 0 for BOD, 1 for TSS, or 2 for CEC");
        }

        if (!Double.isFinite(observation.normalizedValue())
            || observation.normalizedValue() < 0.0d
            || observation.normalizedValue() > 1.0d) {
            throw new IllegalArgumentException("normalizedValue must be finite and within [0, 1]");
        }

        if (!Double.isFinite(observation.variance()) || observation.variance() <= 0.0d) {
            throw new IllegalArgumentException("observation variance must be finite and positive");
        }

        if (observation.observationId() <= 0L) {
            throw new IllegalArgumentException("observationId must be positive");
        }
    }

    private static double[][] copyMatrix(final double[][] matrix) {
        final double[][] copy = new double[STATE_SIZE][STATE_SIZE];
        for (int row = 0; row < STATE_SIZE; row++) {
            System.arraycopy(matrix[row], 0, copy[row], 0, STATE_SIZE);
        }
        return copy;
    }

    private static void copyInto(final double[][] source, final double[][] destination) {
        for (int row = 0; row < STATE_SIZE; row++) {
            System.arraycopy(source[row], 0, destination[row], 0, STATE_SIZE);
        }
    }

    private static double clampUnitInterval(final double value) {
        return Math.max(0.0d, Math.min(1.0d, value));
    }
}
