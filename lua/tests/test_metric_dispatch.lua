local dispatcher = require("metric_dispatch")
local prohibited_keys = require("prohibited_keys")

local function assert_true(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(
            message
                or ("expected " .. tostring(expected)
                    .. ", got " .. tostring(actual))
        )
    end
end

local function test_direct_person_identifier_is_rejected()
    local response, error_response = dispatcher.dispatch({
        metric = "surface_burn_clock",
        input = {
            person_id = "not-permitted",
            material = "asphalt",
            air_temperature_c = 43.0,
            solar_radiation_w_m2 = 950.0,
            wind_speed_m_s = 2.0,
            shade_fraction = 0.0,
            surface_moisture_fraction = 0.0,
            sun_exposure_minutes = 210.0,
            observation_coverage = 0.95,
            evidence_quality = 0.90,
        },
    })

    assert_equal(response, nil)
    assert_equal(error_response.error_code, "prohibited_key")
end

local function test_nested_device_identifier_is_rejected()
    local valid, error_value = prohibited_keys.validate({
        environment = {
            device_id = "not-permitted",
        },
    })

    assert_true(not valid)
    assert_equal(error_value.code, "prohibited_key")
    assert_equal(error_value.path, "$.environment.device_id")
end

local function test_surface_burn_clock_returns_governed_result()
    local response, error_response = dispatcher.dispatch({
        metric = "surface_burn_clock",
        input = {
            material = "asphalt",
            air_temperature_c = 43.0,
            solar_radiation_w_m2 = 950.0,
            wind_speed_m_s = 2.0,
            shade_fraction = 0.0,
            surface_moisture_fraction = 0.0,
            sun_exposure_minutes = 210.0,
            prior_surface_temperature_c = 55.0,
            observation_coverage = 0.95,
            evidence_quality = 0.90,
        },
    })

    assert_equal(error_response, nil)
    assert_true(response.result.estimated_surface_temperature_c ~= nil)
    assert_true(response.governance ~= nil)
    assert_equal(
        response.governance.individual_profiling,
        "prohibited"
    )
    assert_equal(
        response.governance.external_action,
        "not_performed"
    )
end

local function test_insufficient_is_normalized()
    local response, error_response = dispatcher.dispatch({
        metric = "outdoor_hydration_advisory",
        input = {
            air_temperature_c = 42.0,
            relative_humidity_fraction = 0.18,
            solar_radiation_w_m2 = 910.0,
            wind_speed_m_s = 4.0,
            activity_level = 0.50,
            shade_fraction = 0.30,
            work_rest_fraction = 0.25,
            water_access_score = 0.80,
            forecast_coverage = 0.45,
            evidence_quality = 0.80,
        },
    })

    assert_equal(error_response, nil)
    assert_equal(
        response.result.coverage_status,
        "insufficient_coverage"
    )
end

test_direct_person_identifier_is_rejected()
test_nested_device_identifier_is_rejected()
test_surface_burn_clock_returns_governed_result()
test_insufficient_is_normalized()
