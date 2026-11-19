-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: reference-only nutritional research package validation.
-- No network, filesystem, clock, identity inference, or external action.
-- Local reference limits are ASCII byte limits.
-- Findings are append-only. Caller records must not mutate during a call.

local M = {}

local INPUT_VERSION = "nutrition-research-package-v2"
local OUTPUT_VERSION = "nutrition-research-validation-v2"
local CLAIM_VERSION = "nutrition-claims-v1"
local FIELD_BUDGET = 256

local object_set = {
    protein_day_completeness = true,
    food_composition_matching = true
}

local purpose_set = {
    PUBLIC_INTEREST_RESEARCH = true
}

local reference_fields = {
    "request_reference",
    "evidence_reference",
    "policy_reference",
    "consent_reference",
    "prior_aln_admission_reference",
    "allowed_scope_reference",
    "claim_review_reference",
    "appeal_reference"
}

local scalar_fields = {
    "schema_version",
    "research_object",
    "research_purpose",
    "retention_days",
    "issued_day_utc",
    "claim_projection_version"
}

local allowed = {}
for _, name in ipairs(reference_fields) do allowed[name] = true end
for _, name in ipairs(scalar_fields) do allowed[name] = true end

local reason_specs = {
    structure_plain_record_required = { "error", "structure" },
    structure_field_budget_exceeded = { "error", "structure" },
    structure_invalid_key = { "error", "structure" },
    structure_unexpected_field = { "error", "structure" },
    structure_missing_field = { "error", "structure" },
    structure_enum_string_required = { "error", "structure" },
    structure_invalid_retention_days = { "error", "structure" },
    structure_invalid_utc_day_bucket = { "error", "structure" },
    admission_schema_unsupported = { "error", "admission" },
    admission_object_unsupported = { "error", "admission" },
    admission_purpose_unsupported = { "error", "admission" },
    claim_projection_unsupported = { "error", "claims" },
    claim_local_reference_invalid = { "error", "claims" },
    claim_references_unresolved = { "info", "claims" }
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function bounded_integer(value, low, high)
    return finite(value)
        and value % 1 == 0
        and value >= low and value <= high
end

local function local_reference(value)
    if type(value) ~= "string"
        or #value < 7 or #value > 160
        or value:sub(1, 6) ~= "local:" then
        return false
    end

    local body = value:sub(7)
    if body:sub(1, 1) == "/" or body:sub(-1) == "/"
        or body:find("//", 1, true) then
        return false
    end

    for segment in body:gmatch("[^/]+") do
        if not segment:match("^[A-Za-z0-9_-]+$") then
            return false
        end
    end

    return true
end

local function add(output, code, field, count)
    local spec = reason_specs[code]
    assert(spec, "internal finding registry mismatch")

    local finding = {
        code = code,
        field = field,
        severity = spec[1],
        phase = spec[2]
    }
    if count ~= nil then finding.count = count end

    output.findings[#output.findings + 1] = finding
end

local function has_errors(output, phase)
    for _, finding in ipairs(output.findings) do
        if finding.severity == "error" and finding.phase == phase then
            return true
        end
    end
    return false
end

local function structure(record, output)
    if not plain(record) then
        add(output, "structure_plain_record_required", "record")
        return false
    end

    local keys = {}
    local count = 0

    for key in next, record do
        count = count + 1
        if count > FIELD_BUDGET then
            add(output, "structure_field_budget_exceeded", "record")
            output.structural_inventory = "not_completed"
            return false
        end
        keys[#keys + 1] = key
    end

    local invalid = {}
    local opaque_counts = {}
    local unexpected = {}

    for _, key in ipairs(keys) do
        local kind = type(key)
        if kind == "string" then
            if #key > 96 then
                invalid[#invalid + 1] = "string:overlength"
            elseif not allowed[key] then
                unexpected[#unexpected + 1] = key
            end
        elseif kind == "number" then
            local descriptor
            if math.type(key) == "integer" then
                descriptor = tostring(key)
            elseif finite(key) then
                descriptor = string.format("%a", key)
            elseif key > 0 then
                descriptor = "positive_infinity"
            else
                descriptor = "negative_infinity"
            end
            invalid[#invalid + 1] = "number:" .. descriptor
        elseif kind == "boolean" then
            invalid[#invalid + 1] = "boolean:" .. tostring(key)
        else
            opaque_counts[kind] = (opaque_counts[kind] or 0) + 1
        end
    end

    table.sort(invalid)
    for _, descriptor in ipairs(invalid) do
        add(output, "structure_invalid_key", descriptor)
    end

    for _, kind in ipairs({ "function", "table", "thread", "userdata" }) do
        if opaque_counts[kind] then
            add(output, "structure_invalid_key",
                "opaque_key_type:" .. kind, opaque_counts[kind])
        end
    end

    table.sort(unexpected)
    for _, name in ipairs(unexpected) do
        add(output, "structure_unexpected_field", name)
    end

    local missing = {}
    for name in next, allowed do
        if rawget(record, name) == nil then
            missing[#missing + 1] = name
        end
    end
    table.sort(missing)

    for _, name in ipairs(missing) do
        add(output, "structure_missing_field", name)
    end

    for _, name in ipairs({
        "schema_version", "research_object", "research_purpose"
    }) do
        local value = rawget(record, name)
        if value ~= nil and
            (type(value) ~= "string" or #value == 0 or #value > 96) then
            add(output, "structure_enum_string_required", name)
        end
    end

    local retention = rawget(record, "retention_days")
    if retention ~= nil
        and not bounded_integer(retention, 0, 3650) then
        add(output, "structure_invalid_retention_days", "retention_days")
    end

    local issued = rawget(record, "issued_day_utc")
    if issued ~= nil and not bounded_integer(issued, 0, 1000000) then
        add(output, "structure_invalid_utc_day_bucket", "issued_day_utc")
    end

    output.structural_inventory = "completed"
    return true
end

local function enum_candidate(value)
    return type(value) == "string" and #value > 0 and #value <= 96
end

local function admission(record, output)
    local version = rawget(record, "schema_version")
    if enum_candidate(version) and version ~= INPUT_VERSION then
        add(output, "admission_schema_unsupported", "schema_version")
    end

    local object = rawget(record, "research_object")
    if enum_candidate(object) and not object_set[object] then
        add(output, "admission_object_unsupported", "research_object")
    end

    local purpose = rawget(record, "research_purpose")
    if enum_candidate(purpose) and not purpose_set[purpose] then
        add(output, "admission_purpose_unsupported", "research_purpose")
    end
end

local function claims(record, output)
    local projection = rawget(record, "claim_projection_version")
    if projection ~= nil and projection ~= CLAIM_VERSION then
        add(output, "claim_projection_unsupported",
            "claim_projection_version")
    end

    for _, name in ipairs(reference_fields) do
        local value = rawget(record, name)
        if value ~= nil then
            if local_reference(value) then
                output.unresolved_references[
                    #output.unresolved_references + 1] = {
                        field = name,
                        reference = value
                    }
            else
                add(output, "claim_local_reference_invalid", name)
            end
        end
    end

    if #output.unresolved_references > 0 then
        add(output, "claim_references_unresolved", "unresolved_references",
            #output.unresolved_references)
    end
end

function M.validate(record)
    local evidence_verification = "not_performed"
    local output = {
        output_kind = "ValidationResult",
        schema_version = OUTPUT_VERSION,
        validation_status = "structurally_invalid",
        structure_status = "not_assessed",
        admission_status = "not_assessed",
        claim_status = "not_assessed",
        evidence_verification = evidence_verification,
        external_action_authorized = false,
        findings = {},
        unresolved_references = {}
    }

    if not structure(record, output) then
        output.structure_status = "invalid"
        return output
    end

    admission(record, output)
    claims(record, output)

    local structural_error = has_errors(output, "structure")
    local admission_error = has_errors(output, "admission")
    local claim_error = has_errors(output, "claims")

    output.structure_status = structural_error and "invalid" or "valid"
    output.admission_status =
        admission_error and "unsupported_fields_present"
        or (structural_error and "incomplete" or "supported")
    output.claim_status =
        claim_error and "incomplete"
        or (structural_error and "incomplete" or "references_unresolved")

    if structural_error then
        output.validation_status = "structurally_invalid"
    elseif admission_error then
        output.validation_status = "admission_not_supported"
    elseif claim_error then
        output.validation_status = "claims_incomplete"
    else
        output.validation_status = "ready_for_reference_resolution"
    end

    return output
end

function M.contract()
    local codes = {}
    for code, spec in next, reason_specs do
        codes[code] = { severity = spec[1], phase = spec[2] }
    end

    return {
        input_schema = INPUT_VERSION,
        output_schema = OUTPUT_VERSION,
        claim_projection_version = CLAIM_VERSION,
        local_reference_max_bytes = 160,
        field_budget = FIELD_BUDGET,
        retention_days_min = 0,
        retention_days_max = 3650,
        retention_limit_basis = "implementation_profile_not_permission",
        severities = { "error", "warning", "info" },
        reasons = codes
    }
end

return M
