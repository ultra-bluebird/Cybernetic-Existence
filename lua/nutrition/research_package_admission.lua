-- Reference-only research package admission.
-- No personal observations, health inference, persistence, or action.
local M = {}

local metadata = {
    host_did = "didalnorganic-host",
    bostrom_address = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
    authority = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1",
    repository_authority = "mk-bluebird/Cybercore",
    mental_content_inference_forbidden = true,
    person_scoring_forbidden = true,
    raw_biosignal_export_forbidden = true,
    third_party_disclosure_without_consent_forbidden = true
}

local required = {
    "schema_version", "research_object", "request_reference",
    "evidence_reference", "policy_reference", "consent_reference",
    "purpose", "retention_window", "aln_admission_reference",
    "correction_projection_version", "allowed_scope_reference",
    "verified_claims_reference", "appeal_reference", "issued_at_bucket"
}

local allowed = {}
for _, name in ipairs(required) do allowed[name] = true end

local function ref(value)
    return type(value) == "string"
        and #value >= 1 and #value <= 160
        and value:match("^[A-Za-z0-9][A-Za-z0-9_.:/%-]*$") ~= nil
end

local function copy_metadata()
    local value = {}
    for key, item in pairs(metadata) do value[key] = item end
    return value
end

function M.validate(record)
    local output = {
        output_kind = "ValidationResult",
        schema_version = "nutrition-research-admission-v1",
        project_metadata = copy_metadata(),
        validation_status = "incomplete",
        evidence_verification = "not_performed",
        external_action_authorized = false,
        findings = {}
    }

    local function add(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field, severity = "error"
        }
    end

    if type(record) ~= "table" or getmetatable(record) ~= nil then
        add("plain_reference_record_required", "record")
        return output
    end

    local unexpected, invalid_key = {}, false
    local count = 0
    for key in next, record do
        count = count + 1
        if count > 32 then
            add("field_budget_exceeded", "record")
            return output
        end
        if type(key) ~= "string" or #key > 96 then
            invalid_key = true
        elseif not allowed[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_key then add("invalid_field_key", "record") end
    table.sort(unexpected)
    for _, key in ipairs(unexpected) do
        add("unexpected_field", key)
    end

    for _, name in ipairs(required) do
        if not ref(rawget(record, name)) then
            add("bounded_reference_required", name)
        end
    end

    if rawget(record, "schema_version") ~=
        "nutrition-research-package-v1" then
        add("unsupported_schema", "schema_version")
    end

    local object = rawget(record, "research_object")
    if object ~= "protein_day_completeness"
        and object ~= "food_composition_matching" then
        add("unsupported_research_object", "research_object")
    end

    if rawget(record, "purpose") ~= "PUBLIC_INTEREST_RESEARCH" then
        add("purpose_not_admitted", "purpose")
    end

    if #output.findings == 0 then
        output.validation_status = "ready_for_reference_resolution"
    end

    return output
end

return M
