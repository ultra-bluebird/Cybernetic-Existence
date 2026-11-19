local catalog = require("metrics_catalog")
local governance = require("governance")
local prohibited_keys = require("prohibited_keys")

local M = {}

local estimators = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(value, maximum))
end

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function make_error(code, message, metric, details)
    return nil, {
        error_code = code,
        message = message,
        metric = metric,
        details = details,
        governance = governance.standard_block(),
    }
end

local function validate_number_field(name, value, rule)
    if not is_finite_number(value) then
        return false, name .. " must be a finite number"
    end

    if rule.minimum ~= nil and value < rule.minimum then
        return false, name .. " is below its permitted minimum"
    end

    if rule.maximum ~= nil and value > rule.maximum then
        return false, name .. " exceeds its permitted maximum"
    end

    return true, nil
end

local function validate_enum_field(name, value, rule)
    if type(value) ~= "string" then
        return false, name .. " must be a string enum"
    end

    if rule.values[value] ~= true then
        return false, name .. " is not a permitted enum value"
    end

    return true, nil
end

local function validate_input(metric_name, input, schema)
    if type(input) ~= "table" then
        return false, "input must be a table"
    end

    for input_key, input_value in pairs(input) do
        local rule = schema[input_key]

        if rule == nil then
            return false, "unknown input field: " .. input_key
        end

        local valid
        local message

        if rule.kind == "number" then
            valid, message = validate_number_field(
                input_key,
                input_value,
                rule
            )
        elseif rule.kind == "enum" then
            valid, message = validate_enum_field(
                input_key,
                input_value,
                rule
            )
        else
            return false, "unsupported schema kind for " .. input_key
        end

        if not valid then
            return false, message
        end
    end

    for field_name, rule in pairs(schema) do
        if rule.required and input[field_name] == nil then
            return false, "missing required input field: " .. field_name
        end
    end

    return true, nil
end

local function validate_options(metric_name, options, default_options)
    if type(options) ~= "table" then
        return false, "options must be a table"
    end

    for option_name, _ in pairs(options) do
        if default_options[option_name] == nil then
            return false, "unknown option for " .. metric_name .. ": " .. option_name
        end
    end

    return true, nil
end

local function validate_envelope(request)
    if type(request) ~= "table" then
        return false, "request must be a table"
    end

    if type(request.metric) ~= "string" or request.metric == "" then
        return false, "request.metric must be a non-empty string"
    end

    if type(request.input) ~= "table" then
        return false, "request.input must be a table"
    end

    if request.options ~= nil and type(request.options) ~= "table" then
        return false, "request.options must be a table when supplied"
    end

    for key, _ in pairs(request) do
        if key ~= "metric"
            and key ~= "input"
            and key ~= "options"
            and key ~= "contract_version"
        then
            return false, "unknown request envelope field: " .. tostring(key)
        end
    end

    return true, nil
end

local function evaluate_evapotranspiration_cooling(input)
    local et_cooling = 0.45 * input.evapotranspiration_mm_day
    local anthropogenic_warming = 0.018 * input.anthropogenic_heat_w_m2
    local albedo_cooling = 4.0 * input.albedo_fraction
    local vegetation_cooling = 1.2 * input.vegetation_fraction

    local temperature_change = -et_cooling
        + anthropogenic_warming
        - albedo_cooling
        - vegetation_cooling

    local estimated_temperature =
        input.baseline_surface_temperature_c + temperature_change

    local et_ratio = clamp(
        input.evapotranspiration_mm_day / input.reference_et_mm_day,
        0.0,
        1.0
    )

    local heat_pressure = clamp(
        input.anthropogenic_heat_w_m2 / 250.0,
        0.0,
        1.0
    )

    local thermal_relief = clamp(
        (
            et_cooling
            + albedo_cooling
            + vegetation_cooling
            - anthropogenic_warming
        ) / 12.0,
        0.0,
        1.0
    )

    local recovery_opportunity = clamp(
        0.45 * et_ratio
            + 0.35 * thermal_relief
            + 0.20 * input.vegetation_fraction
            - 0.25 * heat_pressure,
        0.0,
        1.0
    )

    local coverage_status = "sufficient"
    if input.observation_coverage < 0.70 then
        coverage_status = "insufficient"
    end

    local interpretation

    if coverage_status == "insufficient" then
        interpretation = "Observation coverage is below the declared minimum. Retain raw inputs for monitoring, but do not use the aggregate estimate for comparative ranking or material allocation decisions."
    elseif temperature_change < 0.0 then
        interpretation = "The modeled aggregate balance indicates net surface cooling relative to the declared baseline, with evapotranspiration, reflectance, and vegetation support outweighing modeled anthropogenic heat pressure."
    else
        interpretation = "The modeled aggregate balance indicates net warming relative to the declared baseline. Review water availability, vegetation condition, shade coverage, albedo, and controllable anthropogenic heat sources."
    end

    return {
        zone_temperature_change_c = temperature_change,
        estimated_surface_temperature_c = estimated_temperature,
        evapotranspiration_cooling_c = et_cooling,
        anthropogenic_heat_warming_c = anthropogenic_warming,
        albedo_cooling_c = albedo_cooling,
        vegetation_support_c = vegetation_cooling,
        recovery_opportunity = recovery_opportunity,
        coverage_adjusted_recovery_opportunity =
            recovery_opportunity
            * input.observation_coverage
            * input.evidence_quality,
        coverage_status = coverage_status,
        interpretation = interpretation,
    }
end

local function evaluate_outdoor_hydration_advisory(input)
    local heat_pressure = clamp(
        (input.air_temperature_c - 20.0) / 25.0,
        0.0,
        1.0
    )

    local dryness_pressure = clamp(
        (0.70 - input.relative_humidity_fraction) / 0.70,
        0.0,
        1.0
    )

    local solar_pressure = clamp(
        input.solar_radiation_w_m2 / 1000.0,
        0.0,
        1.0
    )

    local wind_pressure = clamp(
        input.wind_speed_m_s / 12.0,
        0.0,
        1.0
    )

    local environmental_demand = clamp(
        0.10
            + 0.35 * heat_pressure
            + 0.12 * dryness_pressure
            + 0.20 * solar_pressure
            + 0.08 * wind_pressure
            + 0.55 * input.activity_level
            - 0.18 * input.shade_fraction
            - 0.20 * input.work_rest_fraction,
        0.0,
        1.50
    )

    local coverage_status = "sufficient"
    if input.forecast_coverage * input.evidence_quality < 0.70 then
        coverage_status = "insufficient"
    end

    local advisory_band
    local advisory_text

    if coverage_status == "insufficient" then
        advisory_band = "insufficient_coverage"
        advisory_text = "Forecast coverage is insufficient for a reliable environmental hydration-demand advisory. Use current official heat guidance, shade, rest, potable-water access, and local safety protocols."
    elseif environmental_demand < 0.35 then
        advisory_band = "low"
        advisory_text = "Environmental water-loss demand is comparatively low for the declared outdoor conditions and activity category. Maintain access to potable water and continue to monitor changing conditions."
    elseif environmental_demand < 0.70 then
        advisory_band = "elevated"
        advisory_text = "Environmental water-loss demand is elevated. Plan regular water access, shade or cooling opportunities, and task pacing."
    elseif environmental_demand < 1.05 then
        advisory_band = "high"
        advisory_text = "Environmental water-loss demand is high. Shift nonessential outdoor tasks to cooler periods, increase rest and shaded recovery access, and ensure readily available potable water."
    else
        advisory_band = "very_high"
        advisory_text = "Environmental water-loss demand is very high. Favor postponement or rescheduling of nonessential strenuous outdoor activity; provide shade, cooling, rest, and accessible potable-water infrastructure."
    end

    return {
        environmental_water_loss_demand_l_h = environmental_demand,
        advisory_band = advisory_band,
        recovery_priority_score = clamp(
            0.55 * (environmental_demand / 1.50)
                + 0.25 * (1.0 - input.water_access_score)
                + 0.20 * (1.0 - input.work_rest_fraction),
            0.0,
            1.0
        ),
        coverage_adjusted_demand_l_h =
            environmental_demand
            * input.forecast_coverage
            * input.evidence_quality,
        coverage_status = coverage_status,
        advisory_text = advisory_text,
        safety_notes = {
            "This is not a medical assessment, diagnosis, or personal hydration prescription.",
            "Thirst alone may not be a sufficient cue in heat; use established workplace or public-health protocols.",
            "Individual needs differ materially with health, acclimatization, clothing, work-rest schedule, prior intake, and other private factors not modeled here.",
            "Do not encourage excessive drinking; follow applicable health and occupational guidance.",
            "Seek urgent help under applicable local protocols if a person shows signs of heat illness or cannot safely continue activity.",
        },
    }
end

local function evaluate_surface_burn_clock(input)
    local profiles = {
        asphalt = {
            solar_absorptivity = 0.92,
            convective_heat_transfer_w_m2_k = 14.0,
            thermal_response_time_minutes = 70.0,
            longwave_retention_factor = 0.78,
            moisture_cooling_factor = 0.10,
        },
        concrete = {
            solar_absorptivity = 0.65,
            convective_heat_transfer_w_m2_k = 13.0,
            thermal_response_time_minutes = 95.0,
            longwave_retention_factor = 0.70,
            moisture_cooling_factor = 0.12,
        },
        metal = {
            solar_absorptivity = 0.72,
            convective_heat_transfer_w_m2_k = 20.0,
            thermal_response_time_minutes = 25.0,
            longwave_retention_factor = 0.45,
            moisture_cooling_factor = 0.0,
        },
        turf = {
            solar_absorptivity = 0.62,
            convective_heat_transfer_w_m2_k = 16.0,
            thermal_response_time_minutes = 45.0,
            longwave_retention_factor = 0.42,
            moisture_cooling_factor = 0.36,
        },
        soil = {
            solar_absorptivity = 0.70,
            convective_heat_transfer_w_m2_k = 12.0,
            thermal_response_time_minutes = 85.0,
            longwave_retention_factor = 0.58,
            moisture_cooling_factor = 0.28,
        },
        brick = {
            solar_absorptivity = 0.74,
            convective_heat_transfer_w_m2_k = 12.5,
            thermal_response_time_minutes = 100.0,
            longwave_retention_factor = 0.72,
            moisture_cooling_factor = 0.08,
        },
    }

    local profile = profiles[input.material]
    local effective_solar =
        input.solar_radiation_w_m2 * (1.0 - input.shade_fraction)

    local solar_equilibrium_delta =
        profile.solar_absorptivity
        * effective_solar
        / profile.convective_heat_transfer_w_m2_k

    local solar_response =
        1.0 - math.exp(
            -input.sun_exposure_minutes
            / profile.thermal_response_time_minutes
        )

    local direct_solar_gain = solar_equilibrium_delta * solar_response
    local convective_relief =
        direct_solar_gain
        * 0.20
        * clamp(input.wind_speed_m_s / 15.0, 0.0, 1.0)

    local moisture_relief =
        direct_solar_gain
        * profile.moisture_cooling_factor
        * input.surface_moisture_fraction

    local retained_heat = 0.0
    if input.prior_surface_temperature_c ~= nil then
        retained_heat = math.max(
            0.0,
            input.prior_surface_temperature_c - input.air_temperature_c
        )
            * profile.longwave_retention_factor
            * math.exp(
                -input.sun_exposure_minutes
                / (profile.thermal_response_time_minutes * 2.0)
            )
    end

    local estimated_surface_temperature =
        input.air_temperature_c
        + direct_solar_gain
        + retained_heat
        - convective_relief
        - moisture_relief

    local hazard_score = clamp(
        (estimated_surface_temperature - 43.0) / (49.0 - 43.0),
        0.0,
        1.0
    )

    local coverage_status = "sufficient"
    if input.observation_coverage * input.evidence_quality < 0.70 then
        coverage_status = "insufficient"
    end

    local hazard_band
    local public_message

    if coverage_status == "insufficient" then
        hazard_band = "insufficient_coverage"
        public_message = "Surface-data coverage is insufficient for a reliable burn-clock advisory. Treat sun-exposed pavement, metal, turf, and play surfaces with caution and verify conditions directly where safe to do so."
    elseif estimated_surface_temperature < 43.0 then
        hazard_band = "low"
        public_message = "Estimated surface conditions are below the configured contact-concern threshold. Continue checking surfaces because direct sunlight, material color, and local shading can change quickly."
    elseif estimated_surface_temperature < 49.0 then
        hazard_band = "elevated"
        public_message = "Sun-exposed surface conditions may create a contact-burn concern. Use shade, footwear, mobility-safe routes, and cooler surfaces where available; do not treat air temperature as a surface-temperature proxy."
    elseif estimated_surface_temperature < 59.0 then
        hazard_band = "high"
        public_message = "Estimated surface conditions are high-risk for contact injury during sustained exposure. Prioritize shaded routes, protected rest areas, surface barriers, and alternative timing for outdoor activity."
    else
        hazard_band = "severe"
        public_message = "Estimated sun-exposed surface conditions are severe. Avoid direct skin contact with exposed pavement, metal, turf, and similar surfaces; activate shaded-route, mobility-support, and cool-surface measures."
    end

    return {
        estimated_surface_temperature_c = estimated_surface_temperature,
        estimated_surface_temperature_f =
            estimated_surface_temperature * 9.0 / 5.0 + 32.0,
        direct_solar_gain_c = direct_solar_gain,
        convective_relief_c = convective_relief,
        moisture_relief_c = moisture_relief,
        retained_heat_c = retained_heat,
        contact_hazard_score = hazard_score,
        hazard_band = hazard_band,
        coverage_adjusted_hazard_score =
            hazard_score
            * input.observation_coverage
            * input.evidence_quality,
        coverage_status = coverage_status,
        public_message = public_message,
        model_notes = {
            "Surface temperature is strongly affected by material, color, solar exposure, shade, wind, moisture, geometry, and retained heat.",
            "This model does not replace calibrated infrared, contact-probe, or satellite surface-temperature observations.",
            "Hazard bands are public environmental warnings, not injury predictions or medical determinations.",
            "Do not infer a person's medical condition, disability, footwear, mobility, housing status, or ability to avoid a surface from this result.",
        },
    }
end

local function evaluate_dry_recovery_service_need(input)
    local weather_load = clamp(
        0.40 * input.wet_exposure_score
            + 0.35 * input.drying_lack_score
            + 0.25 * input.humidity_persistence_score,
        0.0,
        1.0
    )

    local recovery_capacity = (
        input.covered_rest_capacity_score
            + input.dry_storage_capacity_score
            + input.laundry_or_drying_access_score
            + input.hygiene_access_score
            + input.accessible_service_route_score
    ) / 5.0

    local dry_recovery_gap = clamp(
        weather_load - recovery_capacity,
        0.0,
        1.0
    )

    local coverage = input.forecast_coverage
        * input.service_inventory_coverage
        * input.evidence_quality

    local service_band
    local actions
    local interpretation

    if coverage < 0.70 then
        service_band = "insufficient_coverage"
        actions = {
            "Verify weather forecasts, facility hours, and service-inventory records.",
            "Do not rank zones or make material allocation decisions from incomplete coverage.",
            "Maintain accessible channels for service providers and community members to report correction needs.",
        }
        interpretation = "Available weather or service-inventory evidence is insufficient for a reliable dry-recovery planning signal."
    elseif dry_recovery_gap < 0.20 then
        service_band = "routine_monitoring"
        actions = {
            "Maintain routine covered-rest, drying, hygiene, storage, and route-access checks.",
            "Publish current service hours and accessibility information in plain language.",
        }
        interpretation = "Declared recovery capacity appears broadly aligned with the measured wetness and humidity service load for this aggregate service zone."
    elseif dry_recovery_gap < 0.45 then
        service_band = "prepare_capacity"
        actions = {
            "Confirm continuity of covered rest, dry storage, hygiene, and laundry or drying access.",
            "Extend plain-language service communications before forecast wet periods.",
            "Inspect accessible routes and weather protection at service entry points.",
        }
        interpretation = "The zone shows a developing dry-recovery service gap. Prepare capacity and inspect whether recovery services remain accessible."
    elseif dry_recovery_gap < 0.70 then
        service_band = "activate_support"
        actions = {
            "Activate additional covered rest, drying, hygiene, dry-storage, and accessible route support.",
            "Extend service hours where community-governed capacity permits.",
            "Coordinate material supply continuity for dry clothing, blankets, footwear protection, and document-safe storage.",
        }
        interpretation = "The measured environmental load exceeds declared recovery capacity. Activate voluntary, non-coercive material support and accessible service continuity measures."
    else
        service_band = "urgent_service_gap"
        actions = {
            "Prioritize immediate expansion of covered rest, drying, hygiene, dry-storage, and accessible transport or route support.",
            "Coordinate with public-health, housing, accessibility, and community service partners using voluntary and non-coercive practice.",
            "Publish real-time service availability and correction channels without collecting unnecessary personal data.",
        }
        interpretation = "The aggregate environmental load substantially exceeds declared dry-recovery service capacity. This indicates an urgent systems and infrastructure gap, not a claim about any person or community."
    end

    local coverage_status = "sufficient"
    if coverage < 0.70 then
        coverage_status = "insufficient"
    end

    return {
        weather_load_score = weather_load,
        recovery_capacity_score = recovery_capacity,
        dry_recovery_gap_score = dry_recovery_gap,
        coverage_adjusted_gap_score = dry_recovery_gap * coverage,
        service_band = service_band,
        coverage_status = coverage_status,
        suggested_service_actions = actions,
        interpretation = interpretation,
    }
end

estimators.evapotranspiration_cooling = evaluate_evapotranspiration_cooling
estimators.outdoor_hydration_advisory = evaluate_outdoor_hydration_advisory
estimators.surface_burn_clock = evaluate_surface_burn_clock
estimators.dry_recovery_service_need = evaluate_dry_recovery_service_need

function M.dispatch(request)
    local envelope_ok, envelope_error = validate_envelope(request)
    if not envelope_ok then
        return make_error("invalid_request", envelope_error, nil, nil)
    end

    if request.contract_version ~= nil
        and request.contract_version ~= catalog.contract_version
    then
        return make_error(
            "contract_mismatch",
            "Request contract version does not match the Lua metric contract.",
            request.metric,
            nil
        )
    end

    local metric_definition = catalog.get(request.metric)
    if metric_definition == nil then
        return make_error(
            "unsupported_metric",
            "Requested metric is not supported by the aggregate environmental catalog.",
            request.metric,
            nil
        )
    end

    local privacy_ok, privacy_error = prohibited_keys.validate(request.input, "$.input")
    if not privacy_ok then
        return make_error(
            "prohibited_key",
            "Aggregate-only request rejected by protected-key policy.",
            request.metric,
            privacy_error
        )
    end

    local options = request.options or {}
    local options_ok, options_error = validate_options(
        request.metric,
        options,
        metric_definition.default_options
    )

    if not options_ok then
        return make_error(
            "unknown_option",
            options_error,
            request.metric,
            nil
        )
    end

    local input_ok, input_error = validate_input(
        request.metric,
        request.input,
        metric_definition.input_schema
    )

    if not input_ok then
        return make_error(
            "invalid_input",
            input_error,
            request.metric,
            nil
        )
    end

    local estimator = estimators[request.metric]
    if estimator == nil then
        return make_error(
            "native_estimator_unavailable",
            "Lua native implementation is not available for this metric.",
            request.metric,
            nil
        )
    end

    local result = estimator(request.input)

    local response = {
        metric = request.metric,
        contract_version = catalog.contract_version,
        result = result,
    }

    return governance.attach(response), nil
end

return M
