-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: local declaration admission, not an ALN parser.
-- No nutrition imports, inference, persistence, network, or action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local permitted = {
    gov_resources_are_rights = true,
    gov_forbid_tokenization = true,
    gov_forbid_financialization = true,
    gov_forbid_gambling = true
}

local required = {
    "gov_resources_are_rights",
    "gov_forbid_tokenization",
    "gov_forbid_financialization",
    "gov_forbid_gambling"
}

local function result()
    return {
        gov_boundary_schema = "nutrition-declaration-boundary-v1",
        gov_admission_status = "unresolved",
        gov_authority_status = "not_assessed",
        gov_source_authenticity_status = "not_assessed",
        gov_envelope_evaluation = "not_performed",
        gov_nutrition_estimation = "not_performed",
        gov_external_action_authorized = false,
        gov_access_condition_created = false,
        gov_findings = {}
    }
end

local function finding(output, code, field)
    local entry = { gov_code = code }
    if field ~= nil then
        entry.gov_field = field
    end
    output.gov_findings[#output.gov_findings + 1] = entry
end

function M.admit(declarations)
    local output = result()

    if type(declarations) ~= "table"
        or getmetatable(declarations) ~= nil then
        finding(output, "plain_declaration_record_required")
        return output
    end

    local names = {}
    local count = 0

    for key in next, declarations do
        count = count + 1
        if count > 32 then
            finding(output, "declaration_field_limit_exceeded")
            return output
        end

        if type(key) ~= "string" or #key > 96 then
            finding(output, "invalid_declaration_field_name")
            return output
        end

        names[#names + 1] = key
    end

    table.sort(names)

    for _, name in ipairs(names) do
        if not permitted[name] then
            finding(output, "outside_declaration_boundary", name)
        end
    end

    for _, name in ipairs(required) do
        local value = rawget(declarations, name)
        if value == nil then
            finding(output, "required_declaration_unavailable", name)
        elseif type(value) ~= "boolean" then
            finding(output, "boolean_declaration_required", name)
        elseif value ~= true then
            finding(output, "required_declaration_not_supported", name)
        end
    end

    if #output.gov_findings ~= 0 then
        return output
    end

    output.gov_admission_status = "admitted_declarations_only"
    output.gov_projection = {
        gov_projection_schema = "nutrition-rights-constraints-v1",
        gov_resources_are_rights = true,
        gov_forbid_financialization = true,
        gov_forbid_gambling = true,
        gov_shard_domain_forbid_tokenization = true,
        gov_intake_labels_create_authority = false,
        gov_nutrition_to_envelope_conversion_permitted = false,
        gov_envelope_to_nutrition_conversion_permitted = false,
        gov_access_requires_intake_record = false,
        gov_access_requires_bci_metadata = false,
        gov_access_requires_envelope_compliance = false
    }

    return output
end

return M
