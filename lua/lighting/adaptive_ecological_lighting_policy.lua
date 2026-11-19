local AdaptiveEcologicalLightingPolicy = {}
AdaptiveEcologicalLightingPolicy.__index = AdaptiveEcologicalLightingPolicy

local VALID_DEPLOYMENT_STATES = {
    simulation_only = true,
    shadow_mode = true,
    qualified_review_required = true,
}

local VALID_SENSOR_HEALTH = {
    healthy = true,
    stale = true,
    fault = true,
}

local VALID_ECOLOGICAL_MODES = {
    routine = true,
    ecological_sensitivity = true,
    weather_visibility = true,
    emergency_safety = true,
}

local function assert_table(value, name)
    if type(value) ~= "table" then
        error(name .. " must be a table", 3)
    end
end

local function assert_boolean(value, name, expected)
    if value ~= expected then
        error(name .. " must be " .. tostring(expected), 3)
    end
end

local function assert_number(value, name, minimum, maximum)
    if type(value) ~= "number" or value < minimum or value > maximum then
        error(name .. " must be a number from " .. tostring(minimum) .. " through " .. tostring(maximum), 3)
    end
end

local function assert_integer(value, name, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
        error(name .. " must be an integer from " .. tostring(minimum) .. " through " .. tostring(maximum), 3)
    end
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function AdaptiveEcologicalLightingPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.adaptive-ecological-lighting-policy/v1" then
        error("Unsupported adaptive lighting policy schema.", 2)
    end

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.accessibility_review_completed,
        "policy.governance.accessibility_review_completed",
        true
    )
    assert_boolean(
        policy.governance.qualified_lighting_designer_review_required,
        "policy.governance.qualified_lighting_designer_review_required",
        true
    )
    assert_boolean(
        policy.governance.ecology_review_completed,
        "policy.governance.ecology_review_completed",
        true
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.camera_capture_enabled, "policy.privacy.camera_capture_enabled", false)
    assert_boolean(policy.privacy.persistent_device_identifier_stored, "policy.privacy.persistent_device_identifier_stored", false)
    assert_boolean(policy.privacy.motion_trajectory_stored, "policy.privacy.motion_trajectory_stored", false)
    assert_boolean(policy.privacy.gait_or_identity_inference_enabled, "policy.privacy.gait_or_identity_inference_enabled", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    assert_table(policy.safety, "policy.safety")
    assert_number(
        policy.safety.accessibility_illuminance_floor_lux,
        "policy.safety.accessibility_illuminance_floor_lux",
        0.1,
        1000
    )
    assert_number(
        policy.safety.safety_illuminance_floor_lux,
        "policy.safety.safety_illuminance_floor_lux",
        0.1,
        1000
    )
    assert_number(
        policy.safety.maximum_illuminance_lux,
        "policy.safety.maximum_illuminance_lux",
        0.1,
        10000
    )
    assert_number(
        policy.safety.maximum_fade_rate_lux_per_second,
        "policy.safety.maximum_fade_rate_lux_per_second",
        0.01,
        1000
    )
    assert_number(
        policy.safety.maximum_cct_rate_kelvin_per_second,
        "policy.safety.maximum_cct_rate_kelvin_per_second",
        1,
        10000
    )

    if policy.safety.maximum_illuminance_lux <
        math.max(
            policy.safety.accessibility_illuminance_floor_lux,
            policy.safety.safety_illuminance_floor_lux
        ) then
        error("Maximum illuminance must not be below the route safety floor.", 2)
    end

    assert_table(policy.ecology, "policy.ecology")
    assert_number(
        policy.ecology.minimum_ecological_cct_kelvin,
        "policy.ecology.minimum_ecological_cct_kelvin",
        1000,
        6500
    )
    assert_number(
        policy.ecology.maximum_ecological_cct_kelvin,
        "policy.ecology.maximum_ecological_cct_kelvin",
        1000,
        6500
    )

    if policy.ecology.minimum_ecological_cct_kelvin >
        policy.ecology.maximum_ecological_cct_kelvin then
        error("Ecological CCT range is invalid.", 2)
    end

    assert_boolean(
        policy.ecology.ecological_dimming_may_override_safety_floor,
        "policy.ecology.ecological_dimming_may_override_safety_floor",
        false
    )

    assert_table(policy.operations, "policy.operations")
    assert_boolean(
        policy.operations.sensor_fault_uses_safe_baseline,
        "policy.operations.sensor_fault_uses_safe_baseline",
        true
    )
    assert_boolean(
        policy.operations.manual_override_requires_reason,
        "policy.operations.manual_override_requires_reason",
        true
    )
    assert_boolean(
        policy.operations.automatic_public_space_enforcement_allowed,
        "policy.operations.automatic_public_space_enforcement_allowed",
        false
    )

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("Unsupported deployment state.", 2)
    end

    return setmetatable({
        policy = policy,
    }, AdaptiveEcologicalLightingPolicy)
end

function AdaptiveEcologicalLightingPolicy:calculate_target(input)
    assert_table(input, "input")

    if not VALID_SENSOR_HEALTH[input.sensor_health] then
        error("Unsupported sensor health state.", 2)
    end

    if not VALID_ECOLOGICAL_MODES[input.ecological_mode] then
        error("Unsupported ecological mode.", 2)
    end

    assert_number(input.scheduled_illuminance_lux, "input.scheduled_illuminance_lux", 0, 10000)
    assert_number(input.motion_boost_lux, "input.motion_boost_lux", 0, 10000)
    assert_number(input.ecological_reduction_lux, "input.ecological_reduction_lux", 0, 10000)
    assert_number(input.current_illuminance_lux, "input.current_illuminance_lux", 0, 10000)
    assert_number(input.current_cct_kelvin, "input.current_cct_kelvin", 1000, 6500)
    assert_number(input.requested_cct_kelvin, "input.requested_cct_kelvin", 1000, 6500)
    assert_number(input.delta_seconds, "input.delta_seconds", 0.001, 3600)

    local safety_floor = math.max(
        self.policy.safety.accessibility_illuminance_floor_lux,
        self.policy.safety.safety_illuminance_floor_lux
    )

    local target_illuminance

    if input.sensor_health ~= "healthy" then
        target_illuminance = math.max(
            safety_floor,
            input.scheduled_illuminance_lux
        )
    else
        target_illuminance =
            input.scheduled_illuminance_lux +
            input.motion_boost_lux -
            input.ecological_reduction_lux

        target_illuminance = math.max(target_illuminance, safety_floor)
    end

    target_illuminance = clamp(
        target_illuminance,
        safety_floor,
        self.policy.safety.maximum_illuminance_lux
    )

    local maximum_illuminance_change =
        self.policy.safety.maximum_fade_rate_lux_per_second *
        input.delta_seconds

    local next_illuminance =
        input.current_illuminance_lux +
        clamp(
            target_illuminance - input.current_illuminance_lux,
            -maximum_illuminance_change,
            maximum_illuminance_change
        )

    local requested_cct = input.requested_cct_kelvin

    if input.ecological_mode == "ecological_sensitivity" then
        requested_cct = clamp(
            requested_cct,
            self.policy.ecology.minimum_ecological_cct_kelvin,
            self.policy.ecology.maximum_ecological_cct_kelvin
        )
    end

    local maximum_cct_change =
        self.policy.safety.maximum_cct_rate_kelvin_per_second *
        input.delta_seconds

    local next_cct =
        input.current_cct_kelvin +
        clamp(
            requested_cct - input.current_cct_kelvin,
            -maximum_cct_change,
            maximum_cct_change
        )

    return {
        target_illuminance_lux = target_illuminance,
        next_illuminance_lux = next_illuminance,
        next_cct_kelvin = next_cct,
        safety_floor_lux = safety_floor,
        ecological_mode = input.ecological_mode,
        route_safety_preserved = next_illuminance >= safety_floor,
        identity_or_trajectory_storage_allowed = false,
        automatic_enforcement_authorized = false,
    }
end

return AdaptiveEcologicalLightingPolicy
