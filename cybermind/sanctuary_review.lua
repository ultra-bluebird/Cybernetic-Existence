-- Lua 5.4.
-- Pure governance-review routing.
-- No I/O, custody, migration, replication, or safety intervention.
-- Import: local sanctuary = require("cybermind.sanctuary_review")
-- Tests: assert(sanctuary.self_test())
--
-- Inputs are supplied assessments, not authenticated findings.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}

local CONDITIONS = {
    "entry_basis",
    "support",
    "communication",
    "exit_procedure",
    "lawful_transition",
    "privacy",
    "independent_review",
    "termination_plan"
}

local CATEGORIES = {
    unfamiliarity = true,
    discomfort = true,
    hypothetical_danger = true,
    documented_threat = true,
    time_critical_emergency = true
}

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

local function integer(value, path)
    if type(value) ~= "number"
        or math.type(value) ~= "integer" or value < 0 then
        fail("INVALID_INTEGER", path, "Expected nonnegative integer")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
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

function M.conditions_check(input, now)
    return protect(function()
        fields(input, {
            scope_note = true,
            conditions = true,
            accountable_role = true,
            review_due = true,
            term_end = true
        }, "sanctuary")

        integer(now, "now")
        text(input.scope_note, "scope_note")
        text(input.accountable_role, "accountable_role")
        local due = integer(input.review_due, "review_due")
        local ending = integer(input.term_end, "term_end")

        if due > ending then
            fail("INVALID_REVIEW_TERM", "review_due",
                "Review must occur no later than the arrangement's term end")
        end

        local allowed = {}
        for _, condition in ipairs(CONDITIONS) do
            allowed[condition] = true
        end
        fields(input.conditions, allowed, "conditions")

        local result = M.metadata()
        result.unmet_conditions = {}
        result.unknown_conditions = {}

        for _, condition in ipairs(CONDITIONS) do
            local value = choice(input.conditions[condition],
                TRI, "conditions." .. condition)
            if value == "not_satisfied" then
                result.unmet_conditions[
                    #result.unmet_conditions + 1
                ] = condition
            elseif value == "unknown" then
                result.unknown_conditions[
                    #result.unknown_conditions + 1
                ] = condition
            end
        end

        result.review_due = now >= due
        result.term_ended = now >= ending

        if result.term_ended then
            result.status = "term_end_requires_authorized_transition_review"
        elseif result.review_due then
            result.status = "fresh_independent_review_required"
        elseif #result.unmet_conditions > 0 then
            result.status = "sanctuary_conditions_not_established"
        elseif #result.unknown_conditions > 0 then
            result.status = "sanctuary_conditions_unresolved"
        else
            result.status = "supplied_conditions_satisfied"
        end

        result.renewal_automatic = false
        result.execution_authority = "none"
        result.scope =
            "Checklist of supplied assertions only; no welfare, consent, "
            .. "legal-status, custody, exit, or migration determination."
        return result
    end)
end

function M.threat_route(input)
    return protect(function()
        fields(input, {
            category = true,
            evidence_note = true,
            specific_harm = true,
            adequate_evidence = true,
            time_critical = true
        }, "threat")

        local category = choice(input.category, CATEGORIES, "category")
        text(input.evidence_note, "evidence_note")
        local specific = choice(input.specific_harm, TRI, "specific_harm")
        local adequate = choice(input.adequate_evidence, TRI, "adequate_evidence")
        local urgent = choice(input.time_critical, TRI, "time_critical")

        local result = M.metadata()
        result.declared_category = category
        result.consistency_issues = {}
        result.route = "clarify_without_adverse_identity_inference"

        if category == "hypothetical_danger" then
            result.route = "investigate_mechanism_and_preventive_options"
        elseif category == "documented_threat"
            or category == "time_critical_emergency" then

            if specific ~= "satisfied" then
                result.consistency_issues[
                    #result.consistency_issues + 1
                ] = "specific_harm_not_established"
            end
            if adequate ~= "satisfied" then
                result.consistency_issues[
                    #result.consistency_issues + 1
                ] = "adequate_evidence_not_established"
            end
            if category == "time_critical_emergency"
                and urgent ~= "satisfied" then
                result.consistency_issues[
                    #result.consistency_issues + 1
                ] = "time_criticality_not_established"
            end

            if #result.consistency_issues > 0 then
                result.route = "human_assessment_of_claim_and_evidence_gaps"
            elseif category == "time_critical_emergency" then
                result.route = "separate_bounded_emergency_authority_review"
            else
                result.route = "independent_proportionate_safety_review"
            end
        end

        result.preservation_instruction =
            "Assess effects on participant-declared essential capabilities; "
            .. "do not infer authority to interrupt unrelated support."
        result.execution_authority = "none"
        result.scope =
            "Routing only; no threat finding, emergency authorization, "
            .. "legal judgment, containment, or restoration performed."
        return result
    end)
end

function M.self_test()
    local conditions = {}
    for _, name in ipairs(CONDITIONS) do conditions[name] = "satisfied" end

    local input = {
        scope_note = "Synthetic bounded support arrangement",
        conditions = conditions,
        accountable_role = "Independent coordinator",
        review_due = 10,
        term_end = 20
    }

    assert(assert(M.conditions_check(input, 1)).status ==
        "supplied_conditions_satisfied")
    assert(assert(M.conditions_check(input, 10)).status ==
        "fresh_independent_review_required")
    assert(assert(M.conditions_check(input, 20)).renewal_automatic == false)

    input.conditions.exit_procedure = "not_satisfied"
    assert(assert(M.conditions_check(input, 1)).status ==
        "sanctuary_conditions_not_established")

    local threat = {
        category = "time_critical_emergency",
        evidence_note = "Synthetic incomplete assessment",
        specific_harm = "satisfied",
        adequate_evidence = "unknown",
        time_critical = "satisfied"
    }
    assert(assert(M.threat_route(threat)).route ==
        "human_assessment_of_claim_and_evidence_gaps")

    threat.adequate_evidence = "satisfied"
    assert(assert(M.threat_route(threat)).route ==
        "separate_bounded_emergency_authority_review")

    local result = assert(M.threat_route(threat))
    result.consistency_issues[1] = "Caller edit"
    assert(#assert(M.threat_route(threat)).consistency_issues == 0)

    return true
end

return M
