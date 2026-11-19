package augmentedhub.fog;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

public final class FogWindowSensitivityAnalyzer {

    public enum TruthLabel {
        UNMODELED,
        MODELED
    }

    public record Observation(
            String hexAnchor,
            Instant observedAt,
            double unmodeledConfidence,
            TruthLabel referenceLabel
    ) {
        public Observation {
            Objects.requireNonNull(hexAnchor, "hexAnchor");
            Objects.requireNonNull(observedAt, "observedAt");
            Objects.requireNonNull(referenceLabel, "referenceLabel");
            if (unmodeledConfidence < 0.0 || unmodeledConfidence > 1.0) {
                throw new IllegalArgumentException("unmodeledConfidence must be within [0, 1]");
            }
        }
    }

    public record WindowSpec(String label, Duration duration) {
        public WindowSpec {
            Objects.requireNonNull(label, "label");
            Objects.requireNonNull(duration, "duration");
            if (label.isBlank() || duration.isZero() || duration.isNegative()) {
                throw new IllegalArgumentException("Window label and positive duration are required");
            }
        }
    }

    public record ConfusionMatrix(
            long truePositive,
            long falsePositive,
            long trueNegative,
            long falseNegative
    ) {
        public long total() {
            return truePositive + falsePositive + trueNegative + falseNegative;
        }

        public double falseWithholdingRate() {
            long denominator = falsePositive + trueNegative;
            return denominator == 0 ? 0.0 : (double) falsePositive / denominator;
        }

        public double falseNegativeRate() {
            long denominator = falseNegative + truePositive;
            return denominator == 0 ? 0.0 : (double) falseNegative / denominator;
        }

        public double accuracy() {
            return total() == 0
                    ? 0.0
                    : (double) (truePositive + trueNegative) / total();
        }
    }

    public record WindowEvaluation(
            WindowSpec window,
            double unmodeledProbability,
            double coverage,
            ConfusionMatrix matrix
    ) {}

    private FogWindowSensitivityAnalyzer() {}

    public static WindowEvaluation evaluate(
            List<Observation> observations,
            WindowSpec window,
            double withholdingThreshold,
            long eligibleAnchorCount
    ) {
        Objects.requireNonNull(observations, "observations");
        Objects.requireNonNull(window, "window");

        if (withholdingThreshold < 0.0 || withholdingThreshold > 1.0) {
            throw new IllegalArgumentException("withholdingThreshold must be within [0, 1]");
        }
        if (eligibleAnchorCount <= 0) {
            throw new IllegalArgumentException("eligibleAnchorCount must be positive");
        }

        Map<String, List<Observation>> grouped = observations.stream()
                .collect(Collectors.groupingBy(
                        item -> item.hexAnchor() + "|" + binStart(item.observedAt(), window.duration())
                ));

        long tp = 0L;
        long fp = 0L;
        long tn = 0L;
        long fn = 0L;
        long unmodeledPredictions = 0L;

        for (List<Observation> bin : grouped.values()) {
            double averageConfidence = bin.stream()
                    .mapToDouble(Observation::unmodeledConfidence)
                    .average()
                    .orElseThrow();

            boolean predictedUnmodeled = averageConfidence >= withholdingThreshold;
            TruthLabel reference = majorityLabel(bin);

            if (predictedUnmodeled) {
                unmodeledPredictions++;
            }

            if (predictedUnmodeled && reference == TruthLabel.UNMODELED) {
                tp++;
            } else if (predictedUnmodeled) {
                fp++;
            } else if (reference == TruthLabel.MODELED) {
                tn++;
            } else {
                fn++;
            }
        }

        long evaluatedBins = grouped.size();
        double probability = evaluatedBins == 0
                ? 0.0
                : (double) unmodeledPredictions / evaluatedBins;

        double coverage = Math.min(
                1.0,
                (double) grouped.keySet().stream()
                        .map(key -> key.substring(0, key.indexOf('|')))
                        .distinct()
                        .count() / eligibleAnchorCount
        );

        return new WindowEvaluation(
                window,
                probability,
                coverage,
                new ConfusionMatrix(tp, fp, tn, fn)
        );
    }

    public static double fogDelta(
            WindowEvaluation first,
            WindowEvaluation second
    ) {
        return Math.abs(
                first.unmodeledProbability() - second.unmodeledProbability()
        );
    }

    public static Optional<WindowEvaluation> chooseWindow(
            List<WindowEvaluation> evaluations,
            double minimumCoverage,
            double maximumFalseNegativeRate,
            double instabilityWeight
    ) {
        if (minimumCoverage < 0.0 || minimumCoverage > 1.0) {
            throw new IllegalArgumentException("minimumCoverage must be within [0, 1]");
        }
        if (maximumFalseNegativeRate < 0.0 || maximumFalseNegativeRate > 1.0) {
            throw new IllegalArgumentException("maximumFalseNegativeRate must be within [0, 1]");
        }
        if (instabilityWeight < 0.0) {
            throw new IllegalArgumentException("instabilityWeight must be non-negative");
        }

        Map<WindowEvaluation, Double> instability = new HashMap<>();

        for (WindowEvaluation candidate : evaluations) {
            double meanDelta = evaluations.stream()
                    .filter(other -> other != candidate)
                    .mapToDouble(other -> fogDelta(candidate, other))
                    .average()
                    .orElse(0.0);
            instability.put(candidate, meanDelta);
        }

        return evaluations.stream()
                .filter(item -> item.coverage() >= minimumCoverage)
                .filter(item -> item.matrix().falseNegativeRate() <= maximumFalseNegativeRate)
                .min(Comparator.comparingDouble(item ->
                        item.matrix().falseWithholdingRate()
                                + instabilityWeight * instability.get(item)
                ));
    }

    private static Instant binStart(Instant instant, Duration duration) {
        long seconds = duration.getSeconds();
        long alignedEpoch = Math.floorDiv(instant.getEpochSecond(), seconds) * seconds;
        return Instant.ofEpochSecond(alignedEpoch);
    }

    private static TruthLabel majorityLabel(List<Observation> observations) {
        long unmodeled = observations.stream()
                .filter(item -> item.referenceLabel() == TruthLabel.UNMODELED)
                .count();

        long modeled = observations.size() - unmodeled;

        return unmodeled >= modeled
                ? TruthLabel.UNMODELED
                : TruthLabel.MODELED;
    }

    public static List<WindowSpec> defaultWindows() {
        List<WindowSpec> windows = new ArrayList<>();
        windows.add(new WindowSpec("hourly", Duration.ofHours(1)));
        windows.add(new WindowSpec("daily", Duration.ofDays(1)));
        windows.add(new WindowSpec("weekly", Duration.ofDays(7)));
        return List.copyOf(windows);
    }
}
