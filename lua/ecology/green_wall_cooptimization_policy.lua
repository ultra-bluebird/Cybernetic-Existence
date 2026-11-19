local GreenWallCooptimizationPolicy = {}
GreenWallCooptimizationPolicy.__index = GreenWallCooptimizationPolicy

local VALID_DEPLOYMENT_STATES = {
    research_only = true,
    shadow_mode = true,
    qualified_review_required = true,
    approved_for_supervisory_recommendations = true,
}

local VALID_WATER_SOURCE_CLASSES = {
    harvested_rainwater = true,
    approved_reclaimed_water = true,
    approved_potable_backup = true,
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

local function assert_non_empty_string(value, name, maximum_length)
    if type(value) ~= "string" or value == "" then
        error(name .. " must be a non-empty string", 3)
    end

    if #value > maximum_length then
        error(name .. " exceeds the maximum length", 3)
    end
end

function GreenWallCooptimizationPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.green-wall-cooptimization-policy/v1" then
        error("Unsupported green wall co-optimization policy schema.", 2)
    end

    assert_non_empty_string(policy.policy_name, "policy.policy_name", 96)

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.qualified_horticulture_review_required,
        "policy.governance.qualified_horticulture_review_required",
        true
    )
    assert_boolean(
        policy.governance.qualified_building_envelope_review_required,
        "policy.governance.qualified_building_envelope_review_required",
        true
    )
    assert_boolean(
        policy.governance.water_system_review_required,
        "policy.governance.water_system_review_required",
        true
    )
    assert_boolean(
        policy.governance.community_ecology_review_completed,
        "policy.governance.community_ecology_review_completed",
        true
    )

    assert_table(policy.plant_protection, "policy.plant_protection")
    assert_number(
        policy.plant_protection.minimum_vwc_fraction,
        "policy.plant_protection.minimum_vwc_fraction",
        0.01,
        0.95
    )
    assert_number(
        policy.plant_protection.maximum_vwc_fraction,
        "policy.plant_protection.maximum_vwc_fraction",
        0.05,
        0.99
    )

    if policy.plant_protection.minimum_vwc_fraction >=
        policy.plant_protection.maximum_vwc_fraction then
        error("Plant VWC range is invalid.", 2)
    end

    assert_boolean(
        policy.plant_protection.dryness_requires_review_before_deferral,
        "policy.plant_protection.dryness_requires_review_before_deferral",
        true
    )

    assert_table(policy.envelope_protection, "policy.envelope_protection")
    assert_boolean(
        policy.envelope_protection.leak_detection_required,
        "policy.envelope_protection.leak_detection_required",
        true
    )
    assert_boolean(
        policy.envelope_protection.overflow_detection_required,
        "policy.envelope_protection.overflow_detection_required",
        true
    )
    assert_boolean(
        policy.envelope_protection.drainage_health_required,
        "policy.envelope_protection.drainage_health_required",
        true
    )
    assert_boolean(
        policy.envelope_protection.automatic_irrigation_on_leak_allowed,
        "policy.envelope_protection.automatic_irrigation_on_leak_allowed",
        false
    )

    assert_table(policy.water, "policy.water")
    assert_boolean(
        policy.water.rainwater_priority_enabled,
        "policy.water.rainwater_priority_enabled",
        true
    )
    assert_boolean(
        policy.water.potable_backup_allowed,
        "policy.water.potable_backup_allowed",
        true
    )
    assert_number(
        policy.water.maximum_irrigation_liters_per_zone_hour,
        "policy.water.maximum_irrigation_liters_per_zone_hour",
        0.01,
        10000
    )
    assert_boolean(
        policy.water.water_quality_validation_required,
        "policy.water.water_quality_validation_required",
        true
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.camera_capture_enabled, "policy.privacy.camera_capture_enabled", false)
    assert_boolean(policy.privacy.person_tracking_enabled, "policy.privacy.person_tracking_enabled", false)
    assert_boolean(policy.privacy.individual_occupancy_data_stored, "policy.privacy.individual_occupancy_data_stored", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("Unsupported deployment state.", 2)
    end

    return setmetatable({
        policy = policy,
    }, GreenWallCooptimizationPolicy)
end

function GreenWallCooptimizationPolicy:evaluate_zone_state(state)
    assert_table(state, "state")

    assert_number(state.vwc_fraction, "state.vwc_fraction", 0, 1)
    assert_number(state.requested_irrigation_liters_per_hour, "state.requested_irrigation_liters_per_hour", 0, 10000)

    if not VALID_WATER_SOURCE_CLASSES[state.water_source_class] then
        error("Unsupported water source class.", 2)
    end

    if state.leak_detected == true then
        return {
            irrigation_permitted = false,
            state = "envelope_review_required",
            reason = "Leak evidence requires qualified building-envelope review before irrigation continues.",
        }
    end

    if state.overflow_detected == true then
        return {
            irrigation_permitted = false,
            state = "drainage_review_required",
            reason = "Overflow evidence requires drainage inspection before irrigation continues.",
        }
    end

    if state.drainage_healthy ~= true then
        return {
            irrigation_permitted = false,
            state = "drainage_review_required",
            reason = "Drainage health is not confirmed.",
        }
    end

    if state.vwc_fraction < self.policy.plant_protection.minimum_vwc_fraction then
        return {
            irrigation_permitted = true,
            state = "plant_protection_priority",
            reason = "Substrate moisture is below the approved plant-protection minimum.",
        }
    end

    if state.vwc_fraction > self.policy.plant_protection.maximum_vwc_fraction then
        return {
            irrigation_permitted = false,
            state = "saturation_protection",
            reason = "Substrate moisture is above the approved maximum.",
        }
    end

    if state.requested_irrigation_liters_per_hour >
        self.policy.water.maximum_irrigation_liters_per_zone_hour then
        return {
            irrigation_permitted = false,
            state = "flow_limit_exceeded",
            reason = "Requested irrigation exceeds the approved zone flow limit.",
        }
    end

    return {
        irrigation_permitted = true,
        state = "within_operating_envelope",
        reason = "Plant moisture, drainage, leak, overflow, and flow constraints permit supervised irrigation planning.",
    }
end

return GreenWallCooptimizationPolicy
