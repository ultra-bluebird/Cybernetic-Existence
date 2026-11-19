package org.augmentedhub.riparian;

import java.util.List;
import java.util.Objects;

public final class RiparianNdviAggregator {
    public record PixelSample(
            double nearInfrared,
            double red,
            boolean valid,
            boolean cloudOrShadowMasked
    ) {}

    public record ZoneSummary(
            double meanNdvi,
            int validPixelCount,
            int excludedPixelCount,
            double validPixelFraction,
            boolean publishable
    ) {}

    public ZoneSummary summarize(
            List<PixelSample> samples,
            int minimumValidPixels,
            double minimumValidFraction) {

        Objects.requireNonNull(samples, "samples");

        if (samples.isEmpty() || minimumValidPixels < 1
                || !Double.isFinite(minimumValidFraction)
                || minimumValidFraction <= 0.0
                || minimumValidFraction > 1.0) {
            throw new IllegalArgumentException("Aggregation parameters are invalid.");
        }

        double ndviSum = 0.0;
        int validCount = 0;
        int excludedCount = 0;

        for (PixelSample sample : samples) {
            Objects.requireNonNull(sample, "sample");

            if (!sample.valid() || sample.cloudOrShadowMasked()) {
                excludedCount++;
                continue;
            }

            if (!Double.isFinite(sample.nearInfrared()) || !Double.isFinite(sample.red())) {
                excludedCount++;
                continue;
            }

            final double denominator = sample.nearInfrared() + sample.red();
            if (Math.abs(denominator) < 1e-12) {
                excludedCount++;
                continue;
            }

            final double ndvi = (sample.nearInfrared() - sample.red()) / denominator;
            if (ndvi < -1.0 || ndvi > 1.0 || !Double.isFinite(ndvi)) {
                excludedCount++;
                continue;
            }

            ndviSum += ndvi;
            validCount++;
        }

        final double validFraction = (double) validCount / samples.size();
        final boolean publishable = validCount >= minimumValidPixels
                && validFraction >= minimumValidFraction;

        return new ZoneSummary(
                validCount == 0 ? Double.NaN : ndviSum / validCount,
                validCount,
                excludedCount,
                validFraction,
                publishable);
    }
}
