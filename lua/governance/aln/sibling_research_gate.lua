-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: local review-record gate for an isolated sibling domain.
-- No ALN parsing, nutrition imports, proof verification, or activation.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local constraint_names = {
    "gov_no_coercive_participation",
    "gov_no_transferable_body_resource_claims",
    "gov_no_direct_actuation",
    "gov_no_nutrition_to_compute_conversion",
    "gov_no_sibling_to_nutrition_inference",
    "gov_access_independent_of_sibling",
    "gov_minimal_disclosure",
    "gov_user_directed_continuity"
}

local check_names = {
    "review_resource_semantics",
    "review_quantity_definitions",
    "review_numeric_encoding",
    "review_contract_scope",
    "review_internal_consistency",
    "review_privacy_and_retention",
    "review_boundary_analysis",
    "review_software_verification"
}

local check_states = {
    not_started = true,
    in_progress = true,
    passed = true,
    failed = true,
    inconclusive = true
}

local accounting_modes = {
    unresolved = true,
    software_operation_accounting = true,
    body_resource_extraction = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function exact_fields(value, names)
    if not plain(value) then
        return false
    end
    local allowed = {}
    for _, name in ipairs(names) do
        allowed[name] = true
    end
    for name in next, value do
        if not allowed[name] then
            return false
        end
    end
    return true
end

local function add(output, code, field)
    output.gov_findings[#output.gov_findings + 1] = {
        gov_code = code,
        gov_field = field
    }
end

function M.evaluate(record)
    local output = {
        gov_gate_schema = "sibling-research-gate-v1",
        gov_placement = "record_unavailable",
        gov_research_status = "unresolved",
        gov_evidence_origin = "caller_supplied_review_record",
        gov_authority_status = "not_assessed",
        gov_authenticity_status = "not_assessed",
        gov_activation_performed = false,
        gov_external_action_authorized = false,
        gov_nutrition_access_affected = false,
        gov_findings = {}
    }

    if not exact_fields(record, {
        "gov_domain",
        "gov_accounting_mode",
        "gov_constraints",
        "gov_review_checks"
    }) then
        add(output, "invalid_review_record")
        return output
    end

    if record.gov_domain ~= "nanoswarm-bio-gas-governance" then
        add(output, "unsupported_sibling_domain", "gov_domain")
        return output
    end

    output.gov_placement = "isolated_research_proposal"

    if not accounting_modes[record.gov_accounting_mode] then
        add(output, "invalid_accounting_mode", "gov_accounting_mode")
        return output
    end

    if not exact_fields(record.gov_constraints, constraint_names)
        or not exact_fields(record.gov_review_checks, check_names) then
        add(output, "invalid_constraint_or_check_fields")
        return output
    end

    local excluded = false
    local incomplete = false

    if record.gov_accounting_mode == "body_resource_extraction" then
        excluded = true
        add(output, "outside_nutrition_connected_scope",
            "gov_accounting_mode")
    elseif record.gov_accounting_mode == "unresolved" then
        incomplete = true
        add(output, "accounting_semantics_unresolved",
            "gov_accounting_mode")
    end

    for _, name in ipairs(constraint_names) do
        local value = rawget(record.gov_constraints, name)
        if value == false then
            excluded = true
            add(output, "required_constraint_not_supported", name)
        elseif value ~= true then
            incomplete = true
            add(output, "required_constraint_unresolved", name)
        end
    end

    for _, name in ipairs(check_names) do
        local state = rawget(record.gov_review_checks, name)
        if not check_states[state] then
            incomplete = true
            add(output, "review_state_unavailable_or_invalid", name)
        elseif state ~= "passed" then
            incomplete = true
            add(output, "review_check_not_passed", name)
        end
    end

    if excluded then
        output.gov_research_status = "excluded_from_connected_scope"
    elseif incomplete then
        output.gov_research_status = "unresolved"
    else
        output.gov_research_status = "ready_for_independent_review"
    end

    return output
end

return M
