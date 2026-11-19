package eco_restoration.residual;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class WorkloadResidualDriftDetector {
    private static final double THREE_SIGMA_LIMIT = 3.0;
    private static final double MINIMUM_STANDARD_DEVIATION = 1e-12;

    private WorkloadResidualDriftDetector() {
    }

    public enum FogState {
        CLEAR,
        HUMAN_REVIEW_PENDING,
        WITHHOLD
    }

    public enum Classification {
        INFORMATIONAL,
        HUMAN_REVIEW_PENDING,
        RECALIBRATION_CANDIDATE,
        DATA_EXPANSION_REQUIRED,
        WITHHELD
    }

    public record ResidualSample(
        String sampleId,
        Instant observedAt,
        double residualValue,
        String modelVersion,
        String calibrationVersion,
        boolean sourceValid,
        boolean parameterCurrent,
        boolean consentScopeValid,
        boolean retentionEligible,
        boolean modelScopeValid,
        boolean methodStable,
        boolean uncertaintyAvailable
    ) {
        public ResidualSample {
            requireText("sampleId", sampleId);
            Objects.requireNonNull(observedAt, "observedAt must not be null");
            requireFiniteNonNegative("residualValue", residualValue);
            requireText("modelVersion", modelVersion);
            requireText("calibrationVersion", calibrationVersion);
        }
    }

    public record DriftConfiguration(
        int minimumSampleCount,
        int persistentAlertCount,
        double sigmaMultiplier
    ) {
        public DriftConfiguration {
            if (minimumSampleCount < 3) {
                throw new IllegalArgumentException(
                    "minimumSampleCount must be at least three."
                );
            }

            if (persistentAlertCount < 1) {
                throw new IllegalArgumentException(
                    "persistentAlertCount must be positive."
                );
            }

            if (!Double.isFinite(sigmaMultiplier) || sigmaMultiplier <= 0.0) {
                throw new IllegalArgumentException(
                    "sigmaMultiplier must be finite and positive."
                );
            }
        }

        public static DriftConfiguration defaultConfiguration() {
            return new DriftConfiguration(8, 3, THREE_SIGMA_LIMIT);
        }
    }

    public record DriftResult(
        double latestResidual,
        double latestDelta,
        double meanDelta,
        double standardDeviationDelta,
        double zScore,
        int recentAlertCount,
        Classification classification,
        FogState fogState,
        String reason
    ) {
    }

    public static DriftResult assess(
        List<ResidualSample> samples,
        DriftConfiguration configuration
    ) {
        Objects.requireNonNull(samples, "samples must not be null");
        Objects.requireNonNull(configuration, "configuration must not be null");

        if (samples.size() < configuration.minimumSampleCount()) {
            return dataExpansionRequired(
                samples,
                "Residual history is too short to establish a stable drift-control window."
            );
        }

        for (ResidualSample sample : samples) {
            if (!sample.sourceValid() ||
                !sample.parameterCurrent() ||
                !sample.consentScopeValid() ||
                !sample.retentionEligible()) {
                return withheld(
                    samples,
                    "Source, parameter, consent, or retention eligibility is not valid."
                );
            }

            if (!sample.modelScopeValid()) {
                return dataExpansionRequired(
                    samples,
                    "Residual evidence is outside the validated model scope."
                );
            }

            if (!sample.uncertaintyAvailable()) {
                return dataExpansionRequired(
                    samples,
                    "Residual uncertainty is unavailable; drift cannot be interpreted safely."
                );
            }
        }

        List<Double> deltas = deltas(samples);
        double mean = mean(deltas);
        double standardDeviation = sampleStandardDeviation(deltas, mean);
        double latestDelta = deltas.get(deltas.size() - 1);

        if (standardDeviation < MINIMUM_STANDARD_DEVIATION) {
            if (Math.abs(latestDelta - mean) < MINIMUM_STANDARD_DEVIATION) {
                return new DriftResult(
                    latestResidual(samples),
                    latestDelta,
                    mean,
                    standardDeviation,
                    0.0,
                    0,
                    Classification.INFORMATIONAL,
                    FogState.CLEAR,
                    "Residual deltas are stable within the configured numerical tolerance."
                );
            }

            return dataExpansionRequired(
                samples,
                "Residual variation is degenerate; a stable control limit cannot be estimated."
            );
        }

        double zScore = (latestDelta - mean) / standardDeviation;
        int recentAlertCount = countRecentAlerts(
            deltas,
            mean,
            standardDeviation,
            configuration.sigmaMultiplier(),
            configuration.persistentAlertCount()
        );

        if (Math.abs(zScore) <= configuration.sigmaMultiplier()) {
            return new DriftResult(
                latestResidual(samples),
                latestDelta,
                mean,
                standardDeviation,
                zScore,
                recentAlertCount,
                Classification.INFORMATIONAL,
                FogState.CLEAR,
                "Latest residual delta is within the configured control limit."
            );
        }

        boolean allMethodsStable = samples.stream()
            .allMatch(ResidualSample::methodStable);

        if (!allMethodsStable) {
            return new DriftResult(
                latestResidual(samples),
                latestDelta,
                mean,
                standardDeviation,
                zScore,
                recentAlertCount,
                Classification.DATA_EXPANSION_REQUIRED,
                FogState.HUMAN_REVIEW_PENDING,
                "A residual alert occurred while method or calibration versions changed."
            );
        }

        if (recentAlertCount >= configuration.persistentAlertCount()) {
            return new DriftResult(
                latestResidual(samples),
                latestDelta,
                mean,
                standardDeviation,
                zScore,
                recentAlertCount,
                Classification.RECALIBRATION_CANDIDATE,
                FogState.HUMAN_REVIEW_PENDING,
                "Persistent statistically unusual residual drift requires human acknowledgment before recalibration."
            );
        }

        return new DriftResult(
            latestResidual(samples),
            latestDelta,
            mean,
            standardDeviation,
            zScore,
            recentAlertCount,
            Classification.HUMAN_REVIEW_PENDING,
            FogState.HUMAN_REVIEW_PENDING,
            "A statistically unusual residual delta requires review before classification."
        );
    }

    private static DriftResult dataExpansionRequired(
        List<ResidualSample> samples,
        String reason
    ) {
        return new DriftResult(
            samples.isEmpty() ? 0.0 : latestResidual(samples),
            0.0,
            0.0,
            0.0,
            0.0,
            0,
            Classification.DATA_EXPANSION_REQUIRED,
            FogState.HUMAN_REVIEW_PENDING,
            reason
        );
    }

    private static DriftResult withheld(
        List<ResidualSample> samples,
        String reason
    ) {
        return new DriftResult(
            samples.isEmpty() ? 0.0 : latestResidual(samples),
            0.0,
            0.0,
            0.0,
            0.0,
            0,
            Classification.WITHHELD,
            FogState.WITHHOLD,
            reason
        );
    }

    private static List<Double> deltas(List<ResidualSample> samples) {
        List<Double> result = new ArrayList<>();

        for (int index = 1; index < samples.size(); index++) {
            result.add(
                samples.get(index).residualValue() -
                samples.get(index - 1).residualValue()
            );
        }

        return result;
    }

    private static double latestResidual(List<ResidualSample> samples) {
        return samples.get(samples.size() - 1).residualValue();
    }

    private static double mean(List<Double> values) {
        return values.stream()
            .mapToDouble(Double::doubleValue)
            .average()
            .orElseThrow(() -> new IllegalArgumentException("Values must not be empty."));
    }

    private static double sampleStandardDeviation(
        List<Double> values,
        double mean
    ) {
        if (values.size() < 2) {
            return 0.0;
        }

        double squaredDifferenceSum = 0.0;

        for (double value : values) {
            double difference = value - mean;
            squaredDifferenceSum += difference * difference;
        }

        return Math.sqrt(squaredDifferenceSum / (values.size() - 1));
    }

    private static int countRecentAlerts(
        List<Double> deltas,
        double mean,
        double standardDeviation,
        double multiplier,
        int maximumCount
    ) {
        int count = 0;

        for (int index = deltas.size() - 1;
             index >= 0 && count < maximumCount;
             index--) {
            double zScore = (deltas.get(index) - mean) / standardDeviation;

            if (Math.abs(zScore) > multiplier) {
                count++;
            } else {
                break;
            }
        }

        return count;
    }

    private static void requireText(String name, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank.");
        }
    }

    private static void requireFiniteNonNegative(String name, double value) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(
                name + " must be finite and non-negative."
            );
        }
    }
}
