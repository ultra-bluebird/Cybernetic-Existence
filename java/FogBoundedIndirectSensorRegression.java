package augmentedhub.fog;

import java.util.Arrays;
import java.util.Objects;

public final class FogBoundedIndirectSensorRegression {

    public record Coefficients(
            double intercept,
            double soilMoistureCoefficient,
            double temperatureCoefficient,
            double lowerBound,
            double upperBound
    ) {
        public Coefficients {
            if (!Double.isFinite(intercept)
                    || !Double.isFinite(soilMoistureCoefficient)
                    || !Double.isFinite(temperatureCoefficient)
                    || !Double.isFinite(lowerBound)
                    || !Double.isFinite(upperBound)
                    || lowerBound >= upperBound) {
                throw new IllegalArgumentException(
                        "Coefficients and ordered finite bounds are required"
                );
            }
        }
    }

    public record ValidationPolicy(
            double maximumMse,
            double maximumAbsoluteError,
            int minimumValidationSamples
    ) {
        public ValidationPolicy {
            if (!Double.isFinite(maximumMse)
                    || maximumMse < 0.0
                    || !Double.isFinite(maximumAbsoluteError)
                    || maximumAbsoluteError < 0.0
                    || minimumValidationSamples < 2) {
                throw new IllegalArgumentException(
                        "Validation limits must be finite and sample count must be at least two"
                );
            }
        }
    }

    public record ValidationResult(
            int sampleCount,
            double meanSquaredError,
            double maximumAbsoluteError,
            boolean suitableForDerivedFogEvidence,
            boolean advisoryOnly,
            boolean directEvidence
    ) {}

    private FogBoundedIndirectSensorRegression() {}

    public static double predict(
            double soilMoisture,
            double temperature,
            Coefficients coefficients
    ) {
        Objects.requireNonNull(coefficients, "coefficients");
        requireFinite(soilMoisture, "soilMoisture");
        requireFinite(temperature, "temperature");

        double raw = coefficients.intercept()
                + coefficients.soilMoistureCoefficient() * soilMoisture
                + coefficients.temperatureCoefficient() * temperature;

        return Math.max(
                coefficients.lowerBound(),
                Math.min(coefficients.upperBound(), raw)
        );
    }

    public static ValidationResult validate(
            double[] predictions,
            double[] directObservations,
            ValidationPolicy policy
    ) {
        Objects.requireNonNull(predictions, "predictions");
        Objects.requireNonNull(directObservations, "directObservations");
        Objects.requireNonNull(policy, "policy");

        if (predictions.length != directObservations.length
                || predictions.length < policy.minimumValidationSamples()) {
            throw new IllegalArgumentException(
                    "Arrays must have equal length and meet the minimum validation sample count"
            );
        }

        double squaredErrorSum = 0.0;
        double maximumAbsoluteError = 0.0;

        for (int index = 0; index < predictions.length; index++) {
            requireFinite(predictions[index], "prediction");
            requireFinite(directObservations[index], "directObservation");

            double error = predictions[index] - directObservations[index];
            squaredErrorSum += error * error;
            maximumAbsoluteError = Math.max(
                    maximumAbsoluteError,
                    Math.abs(error)
            );
        }

        double mse = squaredErrorSum / predictions.length;

        boolean suitable = mse <= policy.maximumMse()
                && maximumAbsoluteError <= policy.maximumAbsoluteError();

        return new ValidationResult(
                predictions.length,
                mse,
                maximumAbsoluteError,
                suitable,
                true,
                false
        );
    }

    public static double[] predictAll(
            double[] soilMoisture,
            double[] temperature,
            Coefficients coefficients
    ) {
        if (soilMoisture.length != temperature.length) {
            throw new IllegalArgumentException(
                    "soilMoisture and temperature must have equal length"
            );
        }

        return Arrays.stream(
                java.util.stream.IntStream.range(0, soilMoisture.length)
                        .mapToDouble(index -> predict(
                                soilMoisture[index],
                                temperature[index],
                                coefficients
                        ))
                        .toArray()
        ).toArray();
    }

    private static void requireFinite(double value, String name) {
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException(
                    name + " must be finite"
            );
        }
    }
}
