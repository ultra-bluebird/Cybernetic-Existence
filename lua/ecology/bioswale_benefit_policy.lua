local BioswaleBenefitPolicy = {}
BioswaleBenefitPolicy.__index = BioswaleBenefitPolicy

local VALID_DEPLOYMENT_STATES = {
    research_only = true,
    pilot_with_human_review = true,
    approved_for_aggregate_reporting = true,
}

local VALID_BENEFIT_CATEGORIES = {
    stormwater_retention = true,
    pollutant_load_reduction = true,
    heat_mitigation = true,
    biodiversity_activity = true,
    soil_carbon_process = true,
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

function BioswaleBenefitPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.bioswale-benefit-policy/v1" then
        error("Unsupported bioswale policy schema.", 2)
    end

    assert_non_empty_string(policy.policy_name, "policy.policy_name")

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.community_review_completed,
        "policy.governance.community_review_completed",
        true
    )
    assert_boolean(
        policy.governance.qualified_hydrology_review_required,
        "policy.governance.qualified_hydrology_review_required",
        true
    )
    assert_boolean(
        policy.governance.qualified_ecology_review_required,
        "policy.governance.qualified_ecology_review_required",
        true
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.camera_capture_enabled, "policy.privacy.camera_capture_enabled", false)
    assert_boolean(policy.privacy.raw_audio_retention_enabled, "policy.privacy.raw_audio_retention_enabled", false)
    assert_boolean(policy.privacy.speech_transcription_enabled, "policy.privacy.speech_transcription_enabled", false)
    assert_boolean(policy.privacy.person_tracking_enabled, "policy.privacy.person_tracking_enabled", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    assert_table(policy.hydrology, "policy.hydrology")
    assert_boolean(
        policy.hydrology.inflow_measurement_required,
        "policy.hydrology.inflow_measurement_required",
        true
    )
    assert_boolean(
        policy.hydrology.outflow_or_storage_measurement_required,
        "policy.hydrology.outflow_or_storage_measurement_required",
        true
    )
    assert_boolean(
        policy.hydrology.rainfall_measurement_required,
        "policy.hydrology.rainfall_measurement_required",
        true
    )
    assert_boolean(
        policy.hydrology.sensor_calibration_required,
        "policy.hydrology.sensor_calibration_required",
        true
    )

    assert_table(policy.reporting, "policy.reporting")
    assert_boolean(
        policy.reporting.uncertainty_required,
        "policy.reporting.uncertainty_required",
        true
    )
    assert_boolean(
        policy.reporting.raw_data_quality_state_required,
        "policy.reporting.raw_data_quality_state_required",
        true
    )
    assert_boolean(
        policy.reporting.composite_score_may_override_missing_category,
        "policy.reporting.composite_score_may_override_missing_category",
        false
    )
    assert_integer(
        policy.reporting.minimum_valid_event_count,
        "policy.reporting.minimum_valid_event_count",
        1,
        100000
    )

    assert_table(policy.reporting.community_weights, "policy.reporting.community_weights")

    local total_weight = 0
    for category, weight in pairs(policy.reporting.community_weights) do
        if not VALID_BENEFIT_CATEGORIES[category] then
            error("Unsupported benefit category weight: " .. category, 2)
        end

        assert_fraction(weight, "policy.reporting.community_weights." .. category)
        total_weight = total_weight + weight
    end

    if total_weight <= 0 then
        error("At least one community benefit weight must be positive.", 2)
    end

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("Unsupported deployment state.", 2)
    end

    return setmetatable({
        policy = policy,
    }, BioswaleBenefitPolicy)
end

function BioswaleBenefitPolicy:validate_event(event)
    assert_table(event, "event")

    assert_non_empty_string(event.event_id, "event.event_id")

    if event.data_quality_state ~= "valid" then
        return {
            eligible_for_reporting = false,
            reason = "The event is not valid for eco-benefit reporting.",
        }
    end

    if type(event.inflow_volume_m3) ~= "number" or event.inflow_volume_m3 < 0 then
        error("event.inflow_volume_m3 must be non-negative.", 2)
    end

    if type(event.outflow_volume_m3) ~= "number" or event.outflow_volume_m3 < 0 then
        error("event.outflow_volume_m3 must be non-negative.", 2)
    end

    if type(event.overflow_volume_m3) ~= "number" or event.overflow_volume_m3 < 0 then
        error("event.overflow_volume_m3 must be non-negative.", 2)
    end

    if type(event.storage_change_m3) ~= "number" then
        error("event.storage_change_m3 must be numeric.", 2)
    end

    local retained = event.inflow_volume_m3 -
        event.outflow_volume_m3 -
        event.overflow_volume_m3 -
        event.storage_change_m3

    if retained < 0 then
        return {
            eligible_for_reporting = false,
            reason = "The event water balance is negative and requires hydrology review.",
        }
    end

    return {
        eligible_for_reporting = true,
        retained_volume_m3 = retained,
        reason = "The event meets the policy requirements for reviewed aggregate reporting.",
    }
end

return BioswaleBenefitPolicy
