-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: structural validation of supplied evidence references.
-- No reference resolution, identity verification, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local allowed = {
    gov_value = true,
    gov_origin = true,
    gov_evidence_ref = true,
    gov_semantics_verification_ref = true
}

local origins = {
    independent_review = true,
    sibling_declaration = true,
    unresolved = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function valid_ref(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= 128
        and value:match("^[A-Za-z0-9][A-Za-z0-9_.:/%-]*$") ~= nil
end

local function add(output, code, field, severity)
    output.gov_findings[#output.gov_findings + 1] = {
        gov_code = code,
        gov_field = field,
        gov_severity = severity
    }
end

function M.validate(record)
    local output = {
        gov_structure_status = "invalid_record",
        gov_reference_readiness = "not_ready",
        gov_origin_verification = "not_performed",
        gov_authenticity_status = "not_assessed",
        gov_authority_status = "not_assessed",
        gov_findings = {}
    }

    if not plain(record) then
        add(output, "plain_evidence_record_required", nil, "error")
        return output
    end

    local unexpected = {}
    local invalid_keys = false
    local count = 0

    for key in next, record do
        count = count + 1
        if count > 16 then
            add(output, "evidence_field_limit_exceeded", nil, "error")
            return output
        end

        if type(key) ~= "string" or #key > 96 then
            invalid_keys = true
        elseif not allowed[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_keys then
        add(output, "invalid_evidence_field_key", nil, "error")
    end

    table.sort(unexpected)
    for _, key in ipairs(unexpected) do
        add(output, "unexpected_evidence_field", key, "error")
    end

    local value = rawget(record, "gov_value")
    if value == nil then
        add(output, "constraint_missing", "gov_value", "error")
    elseif type(value) ~= "boolean" then
        add(output, "constraint_not_boolean", "gov_value", "error")
    end

    local origin = rawget(record, "gov_origin")
    if origin == nil then
        add(output, "origin_missing", "gov_origin", "error")
    elseif type(origin) ~= "string" or not origins[origin] then
        add(output, "origin_invalid", "gov_origin", "error")
    end

    local evidence = rawget(record, "gov_evidence_ref")
    if evidence ~= nil and not valid_ref(evidence) then
        add(output, "evidence_reference_invalid",
            "gov_evidence_ref", "error")
    end

    local semantics = rawget(record, "gov_semantics_verification_ref")
    if semantics ~= nil and not valid_ref(semantics) then
        add(output, "semantics_reference_invalid",
            "gov_semantics_verification_ref", "error")
    end

    if #output.gov_findings ~= 0 then
        return output
    end

    output.gov_structure_status = "well_formed"
    output.gov_declared_value = value
    output.gov_claimed_origin = origin

    if origin == "unresolved" then
        add(output, "origin_unresolved", "gov_origin", "warning")
    end

    if evidence == nil then
        add(output, "evidence_reference_missing",
            "gov_evidence_ref", "warning")
    else
        output.gov_evidence_ref = evidence
    end

    if semantics == nil then
        add(output, "semantics_reference_missing",
            "gov_semantics_verification_ref", "warning")
    else
        output.gov_semantics_verification_ref = semantics
    end

    if #output.gov_findings == 0 then
        output.gov_reference_readiness =
            "ready_for_reference_resolution"
    end

    return output
end

return M
