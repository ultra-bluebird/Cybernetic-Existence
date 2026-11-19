local UrbanEmcMappingPolicy = {}
UrbanEmcMappingPolicy.__index = UrbanEmcMappingPolicy

local VALID_DEPLOYMENT_STATES = {
    research_only = true,
    engineering_review_required = true,
    approved_for_public_aggregate_reporting = true,
}

local VALID_SOURCE_CLASSES = {
    utility_distribution = true,
    transit_traction = true,
    transit_station_equipment = true,
    public_wireless_infrastructure = true,
    public_charging_equipment = true,
    public_building_equipment = true,
    mixed_public_infrastructure = true,
    unknown = true,
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

local function assert_fraction(value, name)
    if type(value) ~= "number" or value < 0 or value > 1 then
        error(name .. " must be a fraction from 0 through 1", 3)
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

function UrbanEmcMappingPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.urban-emc-mapping-policy/v1" then
        error("Unsupported urban EMC mapping policy schema.", 2)
    end

    assert_non_empty_string(policy.policy_name, "policy.policy_name", 96)

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.community_review_completed,
        "policy.governance.community_review_completed",
        true
    )
    assert_boolean(
        policy.governance.qualified_emc_engineer_review_required,
        "policy.governance.qualified_emc_engineer_review_required",
        true
    )
    assert_boolean(
        policy.governance.medical_device_compatibility_claims_allowed,
        "policy.governance.medical_device_compatibility_claims_allowed",
        false
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.implant_registry_enabled, "policy.privacy.implant_registry_enabled", false)
    assert_boolean(policy.privacy.personal_medical_data_stored, "policy.privacy.personal_medical_data_stored", false)
    assert_boolean(policy.privacy.precise_household_mapping_enabled, "policy.privacy.precise_household_mapping_enabled", false)
    assert_boolean(policy.privacy.worker_tracking_enabled, "policy.privacy.worker_tracking_enabled", false)
    assert_boolean(policy.privacy.resident_tracking_enabled, "policy.privacy.resident_tracking_enabled", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    assert_table(policy.measurement, "policy.measurement")
    assert_boolean(
        policy.measurement.calibration_record_required,
        "policy.measurement.calibration_record_required",
        true
    )
    assert_boolean(
        policy.measurement.uncertainty_required,
        "policy.measurement.uncertainty_required",
        true
    )
    assert_boolean(
        policy.measurement.time_band_required,
        "policy.measurement.time_band_required",
        true
    )
    assert_boolean(
        policy.measurement.source_class_required,
        "policy.measurement.source_class_required",
        true
    )
    assert_boolean(
        policy.measurement.interpolation_uncertainty_required,
        "policy.measurement.interpolation_uncertainty_required",
        true
    )

    assert_integer(
        policy.measurement.minimum_aggregate_report_count,
        "policy.measurement.minimum_aggregate_report_count",
        5,
        100000
    )

    assert_table(policy.publication, "policy.publication")
    assert_boolean(
        policy.publication.accessible_text_alternative_required,
        "policy.publication.accessible_text_alternative_required",
        true
    )
    assert_boolean(
        policy.publication.plain_language_limitation_required,
        "policy.publication.plain_language_limitation_required",
        true
    )
    assert_boolean(
        policy.publication.property_or_neighborhood_ranking_allowed,
        "policy.publication.property_or_neighborhood_ranking_allowed",
        false
    )
    assert_boolean(
        policy.publication.individual_safety_guarantee_allowed,
        "policy.publication.individual_safety_guarantee_allowed",
        false
    )

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("Unsupported deployment state.", 2)
    end

    return setmetatable({
        policy = policy,
    }, UrbanEmcMappingPolicy)
end

function UrbanEmcMappingPolicy:validate_measurement(measurement)
    assert_table(measurement, "measurement")

    assert_non_empty_string(measurement.measurement_id, "measurement.measurement_id", 128)
    assert_non_empty_string(measurement.time_band, "measurement.time_band", 64)

    if not VALID_SOURCE_CLASSES[measurement.source_class] then
        error("Unsupported measurement source class.", 2)
    end

    if type(measurement.frequency_hz) ~= "number" or measurement.frequency_hz <= 0 then
        error("measurement.frequency_hz must be positive.", 2)
    end

    if type(measurement.field_value) ~= "number" or measurement.field_value < 0 then
        error("measurement.field_value must be non-negative.", 2)
    end

    if type(measurement.standard_uncertainty) ~= "number" or measurement.standard_uncertainty < 0 then
        error("measurement.standard_uncertainty must be non-negative.", 2)
    end

    assert_fraction(measurement.data_quality_confidence, "measurement.data_quality_confidence")

    if measurement.calibration_current ~= true then
        return {
            usable_for_public_mapping = false,
            engineering_review_required = true,
            reason = "Measurement calibration is not current.",
        }
    end

    if measurement.interpolated == true and measurement.interpolation_standard_deviation == nil then
        return {
            usable_for_public_mapping = false,
            engineering_review_required = true,
            reason = "Interpolated measurements require an interpolation uncertainty value.",
        }
    end

    return {
        usable_for_public_mapping = true,
        engineering_review_required = false,
        reason = "Measurement satisfies calibration and uncertainty policy requirements.",
    }
end

function UrbanEmcMappingPolicy:classify_review_index(index_value, data_quality_confidence)
    assert_fraction(index_value, "index_value")
    assert_fraction(data_quality_confidence, "data_quality_confidence")

    if data_quality_confidence < 0.5 then
        return {
            state = "insufficient_measurement_confidence",
            public_label = "Additional measurement needed",
            medical_compatibility_claim = false,
        }
    end

    if index_value >= 0.8 then
        return {
            state = "engineering_review_priority",
            public_label = "Measured condition under engineering review",
            medical_compatibility_claim = false,
        }
    end

    if index_value >= 0.4 then
        return {
            state = "monitoring_priority",
            public_label = "Measured condition scheduled for monitoring",
            medical_compatibility_claim = false,
        }
    end

    return {
        state = "routine_monitoring",
        public_label = "Measured condition within the current planning range",
        medical_compatibility_claim = false,
    }
end

return UrbanEmcMappingPolicy
