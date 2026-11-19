local AccessiblePathConditionPolicy = {}
AccessiblePathConditionPolicy.__index = AccessiblePathConditionPolicy

local VALID_SURFACE_TYPES = {
    concrete = true,
    asphalt = true,
    pavers = true,
    composite = true,
}

local VALID_DEPLOYMENT_STATES = {
    research_only = true,
    human_review_required = true,
    approved_for_limited_operation = true,
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

local function assert_integer(value, name, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
        error(name .. " must be an integer from " .. tostring(minimum) .. " through " .. tostring(maximum), 3)
    end
end

local function assert_fraction(value, name)
    if type(value) ~= "number" or value < 0 or value > 1 then
        error(name .. " must be a fraction from 0 through 1", 3)
    end
end

local function assert_non_empty_string(value, name)
    if type(value) ~= "string" or value == "" then
        error(name .. " must be a non-empty string", 3)
    end
end

function AccessiblePathConditionPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.accessible-path-condition-policy/v1" then
        error("Unsupported policy schema.", 2)
    end

    assert_non_empty_string(policy.policy_name, "policy.policy_name")

    if not VALID_SURFACE_TYPES[policy.surface_type] then
        error("policy.surface_type is unsupported.", 2)
    end

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.accessibility_review_completed,
        "policy.governance.accessibility_review_completed",
        true
    )
    assert_boolean(
        policy.governance.qualified_inspection_required,
        "policy.governance.qualified_inspection_required",
        true
    )
    assert_boolean(
        policy.governance.accessible_detour_required_before_closure,
        "policy.governance.accessible_detour_required_before_closure",
        true
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.camera_capture_enabled, "policy.privacy.camera_capture_enabled", false)
    assert_boolean(policy.privacy.raw_audio_retention_enabled, "policy.privacy.raw_audio_retention_enabled", false)
    assert_boolean(policy.privacy.user_tracking_enabled, "policy.privacy.user_tracking_enabled", false)
    assert_boolean(policy.privacy.gait_or_device_classification_enabled, "policy.privacy.gait_or_device_classification_enabled", false)
    assert_boolean(policy.privacy.precise_personal_location_stored, "policy.privacy.precise_personal_location_stored", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    assert_table(policy.sensing, "policy.sensing")
    assert_boolean(policy.sensing.fiber_optic_enabled, "policy.sensing.fiber_optic_enabled", true)
    assert_boolean(policy.sensing.accelerometer_enabled, "policy.sensing.accelerometer_enabled", true)
    assert_boolean(policy.sensing.acoustic_emission_enabled, "policy.sensing.acoustic_emission_enabled", true)
    assert_boolean(policy.sensing.sensor_health_monitoring_enabled, "policy.sensing.sensor_health_monitoring_enabled", true)
    assert_boolean(policy.sensing.raw_signal_retention_enabled, "policy.sensing.raw_signal_retention_enabled", false)

    assert_table(policy.thresholds, "policy.thresholds")
    assert_fraction(policy.thresholds.inspection_review_threshold, "policy.thresholds.inspection_review_threshold")
    assert_fraction(policy.thresholds.urgent_human_review_threshold, "policy.thresholds.urgent_human_review_threshold")

    if policy.thresholds.inspection_review_threshold >= policy.thresholds.urgent_human_review_threshold then
        error("Inspection threshold must be below urgent review threshold.", 2)
    end

    assert_integer(
        policy.thresholds.minimum_persistent_windows,
        "policy.thresholds.minimum_persistent_windows",
        1,
        1000
    )

    assert_boolean(
        policy.thresholds.automatic_route_closure_allowed,
        "policy.thresholds.automatic_route_closure_allowed",
        false
    )

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("policy.deployment_state is unsupported.", 2)
    end

    return setmetatable({
        policy = policy,
    }, AccessiblePathConditionPolicy)
end

function AccessiblePathConditionPolicy:classify(degradation_index, persistent_windows, sensor_health)
    assert_fraction(degradation_index, "degradation_index")
    assert_integer(persistent_windows, "persistent_windows", 0, 100000)

    if sensor_health ~= "healthy" then
        return {
            state = "sensor_health_review",
            route_closure_authorized = false,
            reason = "Sensor health is not confirmed; field inspection is required before condition interpretation.",
        }
    end

    if persistent_windows < self.policy.thresholds.minimum_persistent_windows then
        return {
            state = "stable",
            route_closure_authorized = false,
            reason = "The observed change has not persisted across the required evidence windows.",
        }
    end

    if degradation_index >= self.policy.thresholds.urgent_human_review_threshold then
        return {
            state = "urgent_human_review",
            route_closure_authorized = false,
            reason = "A persistent multi-sensor condition signal requires urgent qualified inspection and accessible-continuity review.",
        }
    end

    if degradation_index >= self.policy.thresholds.inspection_review_threshold then
        return {
            state = "inspection_required",
            route_closure_authorized = false,
            reason = "A persistent condition signal requires field inspection.",
        }
    end

    return {
        state = "stable",
        route_closure_authorized = false,
        reason = "No persistent condition signal meets the inspection threshold.",
    }
end

return AccessiblePathConditionPolicy
