-- Lua 5.4.
-- Pure policy-review routing; no inference, copying, or system control.
-- Import: local boundaries = require("cybermind.mental_liberty_boundaries")
-- Tests: assert(boundaries.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}
local YES_NO_UNKNOWN = {yes = true, no = true, unknown = true}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority."
    }
end

function M.inference_route(input)
    return protect(function()
        fields(input, {
            source_kind = true,
            operation_note = true,
            infers_mental_state = true,
            exposes_private_expression = true,
            conditions = true
        }, "inference")

        local source = choice(input.source_kind, {
            neural = true,
            nonneural = true,
            mixed = true,
            unknown = true
        }, "source_kind")
        text(input.operation_note, "operation_note")

        local mental = choice(input.infers_mental_state,
            YES_NO_UNKNOWN, "infers_mental_state")
        local expression = choice(input.exposes_private_expression,
            YES_NO_UNKNOWN, "exposes_private_expression")

        local required = {
            "purpose", "authorization", "minimization",
            "boundary", "retention", "voluntariness"
        }
        local allowed = {}
        for _, name in ipairs(required) do allowed[name] = true end
        fields(input.conditions, allowed, "conditions")

        local result = M.metadata()
        result.source_kind = source
        result.unmet = {}
        result.unknown = {}
        result.mental_information_review =
            mental == "yes" or expression == "yes"
        result.scope_classification_unresolved =
            mental == "unknown" or expression == "unknown"
            or source == "unknown"

        for _, name in ipairs(required) do
            local value = choice(input.conditions[name],
                TRI, "conditions." .. name)
            if value == "not_satisfied" then
                result.unmet[#result.unmet + 1] = name
            elseif value == "unknown" then
                result.unknown[#result.unknown + 1] = name
            end
        end

        if #result.unmet > 0 then
            result.route = "do_not_authorize_this_processing"
        elseif #result.unknown > 0
            or result.scope_classification_unresolved then
            result.route = "resolve_scope_or_conditions_without_compelled_disclosure"
        else
            result.route = "eligible_for_separate_validity_and_authority_checks"
        end

        result.continuity_instruction =
            "Do not use this result to withdraw unrelated appropriate support"
        result.legal_coverage = "not_determined"
        result.execution_authority = "none"
        return result
    end)
end

function M.replication_route(input)
    return protect(function()
        fields(input, {
            operation = true,
            purpose_note = true,
            starts_execution = true,
            transfers_private_state = true,
            affects_essential_capability = true,
            welfare_evidence = true,
            reversibility = true
        }, "replication")

        local operation = choice(input.operation, {
            copy_artifact = true,
            preserve_checkpoint = true,
            initiate_instance = true,
            transfer_state = true,
            terminate_instance = true
        }, "operation")
        text(input.purpose_note, "purpose_note")

        local execution = choice(input.starts_execution,
            YES_NO_UNKNOWN, "starts_execution")
        local private = choice(input.transfers_private_state,
            YES_NO_UNKNOWN, "transfers_private_state")
        local essential = choice(input.affects_essential_capability,
            YES_NO_UNKNOWN, "affects_essential_capability")
        local welfare = choice(input.welfare_evidence, {
            not_assessed = true,
            uncertain = true,
            concern_reported = true
        }, "welfare_evidence")
        local reversibility = choice(input.reversibility, {
            reversible = true,
            partial = true,
            irreversible = true,
            unknown = true
        }, "reversibility")

        if operation == "initiate_instance" and execution ~= "yes" then
            fail("OPERATION_CONFLICT", "starts_execution",
                "Instance initiation must declare execution")
        end
        if (operation == "copy_artifact"
            or operation == "preserve_checkpoint"
            or operation == "terminate_instance")
            and execution ~= "no" then
            fail("COMPOSITE_OPERATION_REQUIRED", "starts_execution",
                "Separate copying, preservation, termination, and initiation")
        end

        local result = M.metadata()
        result.operation = operation
        result.review_routes = {}

        if private ~= "no" then
            result.review_routes[#result.review_routes + 1] =
                "private_state_and_purpose_review"
        end
        if essential ~= "no" then
            result.review_routes[#result.review_routes + 1] =
                "essential_capability_preservation_review"
        end
        if execution ~= "no"
            or operation == "terminate_instance"
            or welfare == "concern_reported" then
            result.review_routes[#result.review_routes + 1] =
                "bounded_machine_welfare_evidence_review"
        end
        if reversibility ~= "reversible" then
            result.review_routes[#result.review_routes + 1] =
                "irreversibility_and_alternatives_review"
        end
        if #result.review_routes == 0 then
            result.review_routes[1] =
                "ordinary_software_licensing_privacy_and_security_checks"
        end

        result.moral_status = "not_determined"
        result.exploitation_finding = "not_determined"
        result.execution_authority = "none"
        result.scope =
            "Routing from supplied operation descriptions only; "
            .. "no system inspection, consciousness finding, copying, "
            .. "preservation, or termination performed."
        return result
    end)
end

function M.self_test()
    local input = {
        source_kind = "nonneural",
        operation_note = "Synthetic text-derived mental-state inference",
        infers_mental_state = "yes",
        exposes_private_expression = "unknown",
        conditions = {
            purpose = "satisfied",
            authorization = "satisfied",
            minimization = "satisfied",
            boundary = "unknown",
            retention = "satisfied",
            voluntariness = "satisfied"
        }
    }

    local result = assert(M.inference_route(input))
    assert(result.mental_information_review)
    assert(result.route ==
        "resolve_scope_or_conditions_without_compelled_disclosure")

    input.conditions.authorization = "not_satisfied"
    assert(assert(M.inference_route(input)).route ==
        "do_not_authorize_this_processing")

    local replication = {
        operation = "copy_artifact",
        purpose_note = "Synthetic software-distribution example",
        starts_execution = "no",
        transfers_private_state = "no",
        affects_essential_capability = "no",
        welfare_evidence = "not_assessed",
        reversibility = "reversible"
    }
    result = assert(M.replication_route(replication))
    assert(result.review_routes[1] ==
        "ordinary_software_licensing_privacy_and_security_checks")

    replication.operation = "initiate_instance"
    local value, err = M.replication_route(replication)
    assert(value == nil and err.code == "OPERATION_CONFLICT")

    replication.starts_execution = "yes"
    result = assert(M.replication_route(replication))
    assert(result.review_routes[1] ==
        "bounded_machine_welfare_evidence_review")
    assert(result.moral_status == "not_determined")

    return true
end

return M
