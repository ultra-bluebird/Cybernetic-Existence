-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Shape validator for an independent scientific-validation record.
--
-- Does not evaluate models, authenticate reviewers, retrieve references,
-- or change the execution summary it references.

local M = {
    VERSION = "1.0.0",
    FORMAT_VERSION = 1,
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function fail(code, field)
    return nil, {
        status = "invalid_request",
        code = code,
        field = field,
    }
end

local function text(value, limit)
    return type(value) == "string"
        and #value > 0
        and #value <= limit
        and value:find("%S") ~= nil
end

local valid_outcomes = {
    supported_within_scope = true,
    not_supported = true,
    inconclusive = true,
    not_assessed = true,
}

local allowed_fields = {
    format_version = true,
    record_reference = true,
    execution_reference = true,
    subject_reference = true,
    scope_reference = true,
    criterion_reference = true,
    comparison_data_reference = true,
    method_reference = true,
    result_reference = true,
    outcome = true,
    reviewer_role_reference = true,
    authentication_state = true,
    limitations_reference = true,
    supersession_reference = true,
}

function M.validate(input)
    if not plain(input) then return fail("record_shape") end

    for key in next, input do
        if not allowed_fields[key] then
            return fail("unknown_field", key)
        end
    end

    if rawget(input, "format_version") ~= M.FORMAT_VERSION then
        return fail("format_version")
    end

    local required = {
        "record_reference",
        "execution_reference",
        "subject_reference",
        "scope_reference",
        "criterion_reference",
        "comparison_data_reference",
        "method_reference",
        "result_reference",
        "outcome",
        "reviewer_role_reference",
        "authentication_state",
        "limitations_reference",
    }

    for _, field in ipairs(required) do
        if rawget(input, field) == nil then
            return fail("field_missing", field)
        end
    end

    for _, field in ipairs({
        "record_reference",
        "execution_reference",
        "subject_reference",
        "scope_reference",
        "criterion_reference",
        "comparison_data_reference",
        "method_reference",
        "result_reference",
        "reviewer_role_reference",
        "limitations_reference",
    }) do
        if not text(rawget(input, field), 512) then
            return fail("field_invalid", field)
        end
    end

    local outcome = rawget(input, "outcome")
    if type(outcome) ~= "string" or not valid_outcomes[outcome] then
        return fail("outcome_invalid", "outcome")
    end

    local authentication = rawget(input, "authentication_state")
    if authentication ~= "not_checked"
        and authentication ~= "valid"
        and authentication ~= "invalid"
        and authentication ~= "unavailable" then
        return fail("authentication_state", "authentication_state")
    end

    local supersession = rawget(input, "supersession_reference")
    if supersession ~= nil and not text(supersession, 512) then
        return fail("field_invalid", "supersession_reference")
    end

    local copy = {}
    for key, value in next, input do copy[key] = value end

    copy.provenance = "independent_validation_record"
    copy.scientific_validation_performed_by_this_module = false
    copy.execution_summary_modified = false
    copy.external_action_authorized = false

    return copy
end

return M
