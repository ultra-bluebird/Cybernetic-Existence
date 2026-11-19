-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: optional hunger/thirst/satiety self-description.
-- No prediction, diagnosis, prompts, persistence, network, or device access.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 24 or not allowed[key] then return false end
    end
    return true
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 512
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function parse_report(record)
    if not shape(record, {
        sensation = true, state = true, format = true,
        reporting_basis = true, content = true,
        scale_min = true, scale_max = true, scale_definition = true
    }) then
        return nil, "invalid_report_shape"
    end

    local sensation = rawget(record, "sensation")
    if sensation ~= "hunger" and sensation ~= "thirst"
        and sensation ~= "satiety" then
        return nil, "unsupported_sensation"
    end

    local basis = rawget(record, "reporting_basis")
    if basis ~= "self_reported" and basis ~= "proxy_reported" then
        return nil, "reporting_basis_required"
    end

    local state = rawget(record, "state")
    if state == "uncertain" or state == "skipped" then
        if rawget(record, "content") ~= nil
            or rawget(record, "format") ~= nil
            or rawget(record, "scale_min") ~= nil
            or rawget(record, "scale_max") ~= nil
            or rawget(record, "scale_definition") ~= nil then
            return nil, "unanswered_report_contains_value_fields"
        end
        return {
            sensation = sensation,
            state = state,
            reporting_basis = basis
        }
    end

    if state ~= "supplied" then
        return nil, "unsupported_report_state"
    end

    local format = rawget(record, "format")
    local content = rawget(record, "content")
    local output = {
        sensation = sensation,
        state = state,
        format = format,
        reporting_basis = basis
    }

    if format == "numeric" then
        local low = rawget(record, "scale_min")
        local high = rawget(record, "scale_max")
        local definition = rawget(record, "scale_definition")

        if not finite(content) or not finite(low) or not finite(high)
            or high <= low or content < low or content > high
            or not text(definition) then
            return nil, "invalid_numeric_report"
        end

        output.content = content
        output.scale_min = low
        output.scale_max = high
        output.scale_definition = definition

    elseif format == "categorical" or format == "symbolic"
        or format == "assistive" then
        if not text(content) or not text(rawget(record, "scale_definition"))
            or rawget(record, "scale_min") ~= nil
            or rawget(record, "scale_max") ~= nil then
            return nil, "invalid_descriptive_report"
        end

        output.content = content
        output.scale_definition = rawget(record, "scale_definition")
    else
        return nil, "unsupported_response_format"
    end

    return output
end

function M.evaluate(input)
    local output = {
        schema_version = "experience-reports-v1",
        capture_status = "not_requested",
        findings = {},
        proposals = {},
        hydration_assessment = "not_performed",
        physiological_deficit_estimation = "not_performed",
        report_prediction = "not_performed",
        persistence_performed = false
    }

    local function finding(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    if not plain(input) then
        finding("plain_input_required", "input")
        return output
    end

    local request = rawget(input, "access_request")
    if request ~= nil then
        if shape(request, { food = true, water = true, human_help = true }) then
            for _, name in ipairs({ "food", "water", "human_help" }) do
                local value = rawget(request, name)
                if value == true then
                    output.proposals[#output.proposals + 1] = {
                        kind = name,
                        external_action_requires_approval = true
                    }
                elseif value ~= nil and type(value) ~= "boolean" then
                    finding("request_boolean_required", name)
                end
            end
        else
            finding("invalid_access_request", "access_request")
        end
    end

    if not shape(input, {
        access_request = true,
        consent_local_experience_processing = true,
        report = true
    }) then
        finding("unsupported_input_fields", "input")
        return output
    end

    local permission =
        rawget(input, "consent_local_experience_processing")

    if permission ~= nil and type(permission) ~= "boolean" then
        finding("permission_boolean_required",
            "consent_local_experience_processing")
    end

    if permission ~= true then
        output.capture_status = "not_processed_without_permission"
        return output
    end

    local report = rawget(input, "report")
    if report == nil then return output end

    local parsed, reason = parse_report(report)
    if parsed == nil then
        output.capture_status = "unavailable_invalid_report"
        finding(reason, "report")
        return output
    end

    output.capture_status = "captured_in_memory"
    output.experience_report = parsed
    return output
end

return M
