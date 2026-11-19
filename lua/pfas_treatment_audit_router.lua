local Router = {}

local permitted_events = {
    treatment_measurement_recorded = true,
    measurement_ready = true,
    measurement_review_required = true,
    measurement_rejected = true,
    mineralization_review_requested = true,
    prohibited_claim_denied = true,
}

local function nonempty_string(value, maximum)
    return type(value) == "string"
        and #value > 0
        and #value <= maximum
        and value:match("%S") ~= nil
end

local function contains_prohibited_material(value)
    if type(value) ~= "string" then
        return false
    end

    local lowered = value:lower()
    return lowered:find("did:", 1, true) ~= nil
        or lowered:find("bostrom", 1, true) ~= nil
        or lowered:find("cyberrank", 1, true) ~= nil
        or lowered:find("compliance", 1, true) ~= nil
        or lowered:find("actuate", 1, true) ~= nil
        or lowered:find("control-command", 1, true) ~= nil
end

function Router.route(event)
    if type(event) ~= "table" then
        return nil, "event must be a table"
    end

    if not permitted_events[event.kind] then
        return nil, "event kind is not permitted"
    end

    if not nonempty_string(event.treatment_run_id, 128)
        or not nonempty_string(event.analyte_id, 128)
        or not nonempty_string(event.audit_time_utc, 32)
        or not nonempty_string(event.result_code, 128) then
        return nil, "required bounded measurement metadata is missing"
    end

    local serialized = table.concat({
        tostring(event.kind or ""),
        tostring(event.treatment_run_id or ""),
        tostring(event.analyte_id or ""),
        tostring(event.audit_time_utc or ""),
        tostring(event.result_code or ""),
        tostring(event.detail or ""),
    }, "\n")

    if contains_prohibited_material(serialized) then
        return nil, "audit event contains prohibited governance, compliance, or control material"
    end

    return {
        route = "local_measurement_audit",
        kind = event.kind,
        treatment_run_id = event.treatment_run_id,
        analyte_id = event.analyte_id,
        audit_time_utc = event.audit_time_utc,
        result_code = event.result_code,
    }
end

return Router
