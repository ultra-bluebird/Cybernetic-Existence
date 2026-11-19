local M = {}

local allowed_event_types = {
    LOW_MIXED_USE = true,
    MODERATE_MIXED_USE = true,
    HIGH_MIXED_USE = true,
    VERY_HIGH_MIXED_USE = true,
    LOW_SPEED_BAND = true,
    MODERATE_SPEED_BAND = true,
    HIGH_SPEED_BAND = true,
    CLEAR_EFFECTIVE_WIDTH = true,
    CONSTRAINED_EFFECTIVE_WIDTH = true,
    OBSTRUCTED_OR_UNCERTAIN_WIDTH = true,
    HEAT_REFUGE_AVAILABLE = true,
    HEAT_REFUGE_UNCERTAIN = true,
    SENSOR_MAINTENANCE_REQUIRED = true
}

local prohibited_keys = {
    person_id = true,
    device_id = true,
    mac_address = true,
    bluetooth_id = true,
    wifi_probe = true,
    face_embedding = true,
    image = true,
    audio = true,
    raw_trajectory = true,
    gait_signature = true,
    health_status = true,
    disability_status = true,
    precise_location_history = true
}

local function is_nonempty_text(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") ~= ""
end

local function is_finite_number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validate_no_prohibited_fields(event)
    for key, _ in pairs(prohibited_keys) do
        if event[key] ~= nil then
            return false, "Prohibited personal or surveillance field: " .. key
        end
    end
    return true
end

function M.aggregate(event)
    if type(event) ~= "table" then
        return nil, "Event must be a table"
    end

    local safe, reason = validate_no_prohibited_fields(event)
    if not safe then
        return nil, reason
    end

    if not is_nonempty_text(event.zone_label) then
        return nil, "zone_label is required"
    end

    if not is_nonempty_text(event.window_start_utc) or not is_nonempty_text(event.window_end_utc) then
        return nil, "A bounded time window is required"
    end

    if not allowed_event_types[event.event_type] then
        return nil, "event_type is not permitted"
    end

    if not is_finite_number(event.confidence) or event.confidence < 0 or event.confidence > 1 then
        return nil, "confidence must be within [0, 1]"
    end

    if not is_finite_number(event.uncertainty) or event.uncertainty < 0 then
        return nil, "uncertainty must be finite and non-negative"
    end

    if not is_nonempty_text(event.evidence_status) then
        return nil, "evidence_status is required"
    end

    local status = "OBSERVE"

    if event.evidence_status == "UNMODELED"
        or event.evidence_status == "EXPIRED"
        or event.confidence < 0.60 then
        status = "HOLD_FOR_REVIEW"
    end

    return {
        zone_label = event.zone_label,
        window_start_utc = event.window_start_utc,
        window_end_utc = event.window_end_utc,
        event_type = event.event_type,
        confidence = event.confidence,
        uncertainty = event.uncertainty,
        evidence_status = event.evidence_status,
        machine_safe_status = status,
        retention_class = "SHORT_LIVED_AGGREGATE_NON_PERSONAL",
        privacy_notice = "This record contains an aggregate environmental or path-condition signal only. It does not identify, track, profile, or score people."
    }
end

return M
