package org.augmentedhub.cyboquatic;

import java.util.Locale;
import java.util.Map;

public final class BiodegradationEvaluator {
    private static final Map<String, Double> THRESHOLDS = Map.of(
        "ISO14851", 60.0,
        "ISO14855", 60.0,
        "OECD301", 60.0,
        "OECD201", 50.0,
        "OECD202", 50.0
    );

    public record Sample(
        String method,
        double blankMgL,
        double inoculumMgL,
        double referenceMgL,
        double testMgL,
        double referencePassDay,
        double testPassDay,
        double temperatureC,
        double ph
    ) {}

    public record Assessment(
        boolean accepted,
        String reason,
        double correctedTestPct,
        double correctedReferencePct,
        double readiness
    ) {}

    private BiodegradationEvaluator() {}

    public static Assessment assess(Sample sample) {
        Double threshold = THRESHOLDS.get(sample.method());
        if (threshold == null) {
            return new Assessment(false, "unsupported_method", 0.0, 0.0, 0.0);
        }

        if (!valid(sample.blankMgL(), 0.0, 100000.0) ||
            !valid(sample.inoculumMgL(), 0.0, 100000.0) ||
            !valid(sample.referenceMgL(), 0.0, 100000.0) ||
            !valid(sample.testMgL(), 0.0, 100000.0) ||
            !valid(sample.referencePassDay(), 0.0, 60.0) ||
            !valid(sample.testPassDay(), 0.0, 60.0) ||
            !valid(sample.temperatureC(), 0.0, 45.0) ||
            !valid(sample.ph(), 4.0, 10.0)) {
            return new Assessment(false, "invalid_measurement_range", 0.0, 0.0, 0.0);
        }

        double denominator = Math.max(sample.referenceMgL() - sample.blankMgL(), 0.001);
        double correctedReference = clamp(
            100.0 * (sample.referenceMgL() - sample.blankMgL()) / denominator, 0.0, 100.0);
        double correctedTest = clamp(
            100.0 * (sample.testMgL() - sample.blankMgL()) / denominator, 0.0, 100.0);

        double biodegradationFactor = clamp(correctedTest / threshold, 0.0, 1.0);
        double referenceFactor = correctedReference >= 95.0 ? 1.0 : correctedReference / 95.0;
        double temperatureFactor = clamp(1.0 - Math.abs(sample.temperatureC() - 20.0) / 20.0, 0.0, 1.0);
        double phFactor = clamp(1.0 - Math.abs(sample.ph() - 7.0) / 3.0, 0.0, 1.0);
        double timingFactor = clamp(1.0 - sample.testPassDay() / 60.0, 0.0, 1.0);

        double readiness = clamp(
            0.50 * biodegradationFactor +
            0.20 * referenceFactor +
            0.15 * temperatureFactor +
            0.10 * phFactor +
            0.05 * timingFactor,
            0.0, 1.0);

        boolean accepted =
            correctedTest >= threshold &&
            correctedReference >= 95.0 &&
            sample.testPassDay() <= 28.0;

        return new Assessment(
            accepted,
            accepted ? "advisory_candidate" : "insufficient_evidence",
            correctedTest,
            correctedReference,
            readiness);
    }

    private static boolean valid(double value, double low, double high) {
        return Double.isFinite(value) && value >= low && value <= high;
    }

    private static double clamp(double value, double low, double high) {
        return Math.max(low, Math.min(high, value));
    }

    public static void main(String[] args) {
        if (args.length != 9) {
            System.err.println("{\"error\":\"expected_9_arguments\"}");
            System.exit(2);
        }

        try {
            Sample sample = new Sample(
                args[0],
                Double.parseDouble(args[1]),
                Double.parseDouble(args[2]),
                Double.parseDouble(args[3]),
                Double.parseDouble(args[4]),
                Double.parseDouble(args[5]),
                Double.parseDouble(args[6]),
                Double.parseDouble(args[7]),
                Double.parseDouble(args[8]));

            Assessment assessment = assess(sample);
            System.out.printf(Locale.ROOT,
                "{\"accepted\":%s,\"reason\":\"%s\",\"corrected_test_pct\":%.6f," +
                "\"corrected_reference_pct\":%.6f,\"readiness\":%.6f,\"mode\":\"advisory_only\"}%n",
                assessment.accepted(),
                assessment.reason(),
                assessment.correctedTestPct(),
                assessment.correctedReferencePct(),
                assessment.readiness());
            System.exit(assessment.accepted() ? 0 : 1);
        } catch (NumberFormatException exception) {
            System.err.println("{\"error\":\"invalid_numeric_argument\"}");
            System.exit(2);
        }
    }
}
