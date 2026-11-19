package org.augmentedhub.thermal;

import java.util.Objects;

public final class ThermalRefugeCalculator {
    public record WeatherObservation(
            double airTemperatureF,
            double relativeHumidityPercent
    ) {}

    public record RefugeInputs(
            double canopyFraction,
            double waterAccessScore,
            double shadeDensity,
            double accessibleAmenityScore,
            double routeAccessScore,
            double localHeatBurdenScore
    ) {}

    public record Weights(
            double canopy,
            double waterAccess,
            double shade,
            double accessibleAmenities,
            double routeAccess,
            double heatBurden
    ) {
        public Weights {
            requireNonNegative(canopy, "canopy");
            requireNonNegative(waterAccess, "waterAccess");
            requireNonNegative(shade, "shade");
            requireNonNegative(accessibleAmenities, "accessibleAmenities");
            requireNonNegative(routeAccess, "routeAccess");
            requireNonNegative(heatBurden, "heatBurden");
        }
    }

    public record Result(
            double heatIndexF,
            boolean heatIndexRegressionApplied,
            double thermalRefugeScore
    ) {}

    public Result calculate(WeatherObservation weather, RefugeInputs input, Weights weights) {
        Objects.requireNonNull(weather, "weather");
        Objects.requireNonNull(input, "input");
        Objects.requireNonNull(weights, "weights");

        validateRange(weather.relativeHumidityPercent(), 0.0, 100.0, "relativeHumidityPercent");
        validateUnitInterval(input.canopyFraction(), "canopyFraction");
        validateUnitInterval(input.waterAccessScore(), "waterAccessScore");
        validateUnitInterval(input.shadeDensity(), "shadeDensity");
        validateUnitInterval(input.accessibleAmenityScore(), "accessibleAmenityScore");
        validateUnitInterval(input.routeAccessScore(), "routeAccessScore");
        validateUnitInterval(input.localHeatBurdenScore(), "localHeatBurdenScore");

        final double preliminary = simpleHeatIndex(
                weather.airTemperatureF(),
                weather.relativeHumidityPercent());

        final boolean applyRegression = preliminary >= 80.0;
        final double heatIndex = applyRegression
                ? rothfuszHeatIndex(
                    weather.airTemperatureF(),
                    weather.relativeHumidityPercent())
                : preliminary;

        final double score =
                weights.canopy() * input.canopyFraction()
                + weights.waterAccess() * input.waterAccessScore()
                + weights.shade() * input.shadeDensity()
                + weights.accessibleAmenities() * input.accessibleAmenityScore()
                + weights.routeAccess() * input.routeAccessScore()
                - weights.heatBurden() * input.localHeatBurdenScore();

        return new Result(heatIndex, applyRegression, score);
    }

    private static double simpleHeatIndex(double temperatureF, double humidityPercent) {
        return 0.5 * (
                temperatureF + 61.0
                + ((temperatureF - 68.0) * 1.2)
                + (humidityPercent * 0.094));
    }

    private static double rothfuszHeatIndex(double temperatureF, double humidityPercent) {
        double index =
                -42.379
                + 2.04901523 * temperatureF
                + 10.14333127 * humidityPercent
                - 0.22475541 * temperatureF * humidityPercent
                - 0.00683783 * temperatureF * temperatureF
                - 0.05481717 * humidityPercent * humidityPercent
                + 0.00122874 * temperatureF * temperatureF * humidityPercent
                + 0.00085282 * temperatureF * humidityPercent * humidityPercent
                - 0.00000199 * temperatureF * temperatureF
                * humidityPercent * humidityPercent;

        if (humidityPercent < 13.0
                && temperatureF >= 80.0
                && temperatureF <= 112.0) {
            index -= ((13.0 - humidityPercent) / 4.0)
                    * Math.sqrt((17.0 - Math.abs(temperatureF - 95.0)) / 17.0);
        } else if (humidityPercent > 85.0
                && temperatureF >= 80.0
                && temperatureF <= 87.0) {
            index += ((humidityPercent - 85.0) / 10.0)
                    * ((87.0 - temperatureF) / 5.0);
        }

        return index;
    }

    private static void validateUnitInterval(double value, String name) {
        validateRange(value, 0.0, 1.0, name);
    }

    private static void validateRange(double value, double minimum, double maximum, String name) {
        if (!Double.isFinite(value) || value < minimum || value > maximum) {
            throw new IllegalArgumentException(name + " must be finite and within its allowed range.");
        }
    }

    private static void requireNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }
}
