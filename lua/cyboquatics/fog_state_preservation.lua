local fog_state_preservation = {}

local function finite_number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function approved_media_class(media_class, approved_media_classes)
    return type(media_class) == "string"
        and media_class ~= ""
        and type(approved_media_classes) == "table"
        and approved_media_classes[media_class] == true
end

function fog_state_preservation.route(input)
    if type(input) ~= "table"
        or type(input.uncertainty_flag) ~= "boolean"
        or not unit_interval(input.classification_confidence)
        or not unit_interval(input.evidence_completeness)
        or not unit_interval(input.knowledge_factor)
        or type(input.chain_of_custody_complete) ~= "boolean"
        or type(input.calibration_record_current) ~= "boolean"
        or type(input.retention_metadata_present) ~= "boolean"
        or type(input.hazard_flag_active) ~= "boolean" then
        return {
            route = "FOG_REVIEW",
            reasons = { "invalid_input" }
        }
    end

    local reasons = {}

    if input.uncertainty_flag then
        table.insert(reasons, "uncertainty_flag")
    end
    if input.classification_confidence < 0.70 then
        table.insert(reasons, "confidence_below_0_70")
    end
    if input.evidence_completeness < 0.90 then
        table.insert(reasons, "completeness_below_0_90")
    end
    if input.knowledge_factor < 0.70 then
        table.insert(reasons, "knowledge_factor_below_0_70")
    end
    if not approved_media_class(input.declared_media_class, input.approved_media_classes) then
        table.insert(reasons, "unapproved_or_unknown_media")
    end
    if not input.chain_of_custody_complete then
        table.insert(reasons, "chain_of_custody_incomplete")
    end
    if not input.calibration_record_current then
        table.insert(reasons, "calibration_record_missing_or_stale")
    end
    if not input.retention_metadata_present then
        table.insert(reasons, "retention_metadata_missing")
    end
    if input.hazard_flag_active then
        table.insert(reasons, "hazard_flag_active")
    end

    if #reasons > 0 then
        return {
            route = "FOG_REVIEW",
            reasons = reasons
        }
    end

    return {
        route = "KNOWN_MEDIA",
        reasons = { "review_prerequisites_passed" }
    }
end

return fog_state_preservation
