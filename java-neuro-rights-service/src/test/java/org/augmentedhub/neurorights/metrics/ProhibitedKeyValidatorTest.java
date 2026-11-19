package org.augmentedhub.neurorights.metrics;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

final class ProhibitedKeyValidatorTest {
    @Test
    void personIdIsRejected() {
        final Map<String, Object> request = new LinkedHashMap<>();

        request.put("metric", "surface_burn_clock");
        request.put("input", Map.of(
            "person_id", "not-permitted",
            "air_temperature_c", 43.0
        ));
        request.put("options", Map.of());

        final ProhibitedKeyValidator.ValidationResult result =
            ProhibitedKeyValidator.validate(request);

        assertFalse(result.allowed());
        assertTrue(result.path().endsWith(".person_id"));
        assertTrue(result.matchedToken().contains("person"));
    }

    @Test
    void nestedDeviceIdIsRejected() {
        final Map<String, Object> request = new LinkedHashMap<>();

        request.put("metric", "surface_burn_clock");
        request.put("input", Map.of(
            "environment", Map.of(
                "device_id", "not-permitted"
            ),
            "air_temperature_c", 43.0
        ));
        request.put("options", Map.of());

        final ProhibitedKeyValidator.ValidationResult result =
            ProhibitedKeyValidator.validate(request);

        assertFalse(result.allowed());
        assertTrue(
            result.path().endsWith(".environment.device_id")
        );
        assertTrue(result.matchedToken().contains("device"));
    }

    @Test
    void activityLevelIsAcceptedForOutdoorHydrationAdvisory() {
        final Map<String, Object> request = new LinkedHashMap<>();

        request.put("metric", "outdoor_hydration_advisory");
        request.put("input", Map.of(
            "air_temperature_c", 42.0,
            "relative_humidity_fraction", 0.18,
            "solar_radiation_w_m2", 910.0,
            "wind_speed_m_s", 4.0,
            "activity_level", 0.50,
            "shade_fraction", 0.30,
            "work_rest_fraction", 0.25,
            "water_access_score", 0.80,
            "forecast_coverage", 0.90,
            "evidence_quality", 0.85
        ));
        request.put("options", Map.of());

        final ProhibitedKeyValidator.ValidationResult result =
            ProhibitedKeyValidator.validate(request);

        assertTrue(result.allowed());
    }
}
