-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: review of supplied human-fallback test observations.
-- No personal intake, BCI signals, network, clock, or external action.
-- Connection windows are defined by the referenced test procedure.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local scenarios = {
    "normal_operation",
    "validation_failure",
    "estimator_unavailable",
    "logging_refused",
    "malformed_accounting_input"
}

local route_states = {
    reachable = true,
    unreachable = true,
    unknown = true
}

local connection_states = {
    connected_within_window = true,
    not_connected_within_window = true,
    not_requested = true,
    unknown = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 16 or not allowed[key] then return false end
    end
    return true
end

local function reference(value)
    return type(value) == "string" and #value <= 128
        and value:match("^local:[A-Za-z0-9_-]+$") ~= nil
end

function M.review(input)
    local output = {
        schema_version = "fallback-evidence-v1",
        status = "unavailable",
        evidence_verification = "not_performed",
        route_matched_count = 0,
        route_barrier_count = 0,
        route_unknown_count = 0,
        connection_within_window_count = 0,
        connection_missed_window_count = 0,
        connection_not_requested_count = 0,
        connection_unknown_count = 0,
        findings = {},
        external_action_performed = false
    }

    local function add(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    if not shape(input, {
        schema_version = true,
        procedure_reference = true,
        results = true
    }) then
        add("invalid_input_shape", "input")
        return output
    end

    if rawget(input, "schema_version") ~= "fallback-test-input-v1"
        or not reference(rawget(input, "procedure_reference")) then
        add("schema_and_procedure_required", "input")
        return output
    end

    local allowed = {}
    for _, name in ipairs(scenarios) do allowed[name] = true end

    local results = rawget(input, "results")
    if not shape(results, allowed) then
        add("invalid_results_shape", "results")
        return output
    end

    local invalid = false
    for _, name in ipairs(scenarios) do
        local result = rawget(results, name)

        if not shape(result, {
            route = true,
            connection = true,
            evidence_reference = true
        }) then
            invalid = true
            add("scenario_record_required", name)
        else
            local route = rawget(result, "route")
            local connection = rawget(result, "connection")

            if type(route) ~= "string" or not route_states[route]
                or type(connection) ~= "string"
                or not connection_states[connection]
                or not reference(rawget(result, "evidence_reference")) then
                invalid = true
                add("invalid_scenario_evidence", name)
            else
                if route == "reachable" then
                    output.route_matched_count =
                        output.route_matched_count + 1
                elseif route == "unreachable" then
                    output.route_barrier_count =
                        output.route_barrier_count + 1
                else
                    output.route_unknown_count =
                        output.route_unknown_count + 1
                end

                if connection == "connected_within_window" then
                    output.connection_within_window_count =
                        output.connection_within_window_count + 1
                elseif connection == "not_connected_within_window" then
                    output.connection_missed_window_count =
                        output.connection_missed_window_count + 1
                elseif connection == "not_requested" then
                    output.connection_not_requested_count =
                        output.connection_not_requested_count + 1
                else
                    output.connection_unknown_count =
                        output.connection_unknown_count + 1
                end
            end
        end
    end

    if invalid then
        output.status = "unavailable_invalid_evidence"
    elseif output.route_barrier_count > 0
        or output.connection_missed_window_count > 0 then
        output.status = "service_barriers_reported"
    elseif output.route_unknown_count > 0
        or output.connection_unknown_count > 0
        or output.connection_not_requested_count > 0 then
        output.status = "end_to_end_evidence_incomplete"
    else
        output.status = "scoped_fallback_success_reported"
    end

    return output
end

return M
