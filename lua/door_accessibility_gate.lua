local M = {}

local function is_boolean(value)
    return type(value) == "boolean"
end

local function has_complete_sensor_data(input)
    return is_boolean(input.thermal_containment_ok)
        and is_boolean(input.air_quality_ok)
        and is_boolean(input.occupancy_ok)
end

local function sensors_are_contradictory(input)
    if input.sensor_state == "contradictory" then
        return true
    end

    if input.occupancy_count ~= nil and input.occupancy_ok ~= nil then
        if type(input.occupancy_count) ~= "number"
            or input.occupancy_count < 0
            or type(input.occupancy_ok) ~= "boolean" then
            return true
        end
    end

    return false
end

local function result(decision, reason, requires_human_review)
    return {
        decision = decision,
        reason = reason,
        requires_human_review = requires_human_review,
    }
end

function M.compute_door_decision(input)
    assert(type(input) == "table", "input must be a table")

    if input.emergency_egress == true then
        return result("hold_open", "EMERGENCY_EGRESS_PRIORITY", true)
    end

    if input.accessibility_request == true and input.active_emergency ~= true then
        return result("open", "ACCESSIBILITY_PRIORITY", false)
    end

    if input.accessibility_request == true and input.active_emergency == true then
        return result(
            "hold_open",
            "ACCESSIBILITY_REQUEST_DURING_ACTIVE_EMERGENCY_USE_EMERGENCY_PLAN",
            true
        )
    end

    if input.sensor_state == "missing"
        or not has_complete_sensor_data(input)
        or sensors_are_contradictory(input) then
        return result("open", "FAIL_OPEN_SENSOR_DATA_UNAVAILABLE_OR_CONTRADICTORY", true)
    end

    if input.thermal_containment_ok
        and input.air_quality_ok
        and input.occupancy_ok then
        return result("open", "ORDINARY_ECO_GATE_SATISFIED", false)
    end

    return result("closed", "ORDINARY_ECO_GATE_NOT_SATISFIED", false)
end

return M
