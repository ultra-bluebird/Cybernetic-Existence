-- Lua 5.4.
-- Pure launch-checklist and authority-scope routing.
-- No I/O, case storage, publication, referral, or binding decisions.
-- Import: local pilot = require("cybermind.pilot_charter_gate")
-- Tests: assert(pilot.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {
    established = true,
    not_established = true,
    unknown = true
}

local REQUIREMENTS = {
    "accountable_operator",
    "published_scope",
    "participation_commitments",
    "accessible_channels",
    "privacy_and_security",
    "retention_and_deletion",
    "independent_appeal",
    "funded_capacity",
    "jurisdiction_review",
    "closure_plan"
}

local ACTIONS = {
    receive_concern = true,
    request_voluntary_information = true,
    facilitate_discussion = true,
    review_commitment = true,
    recommend_action = true,
    track_accepted_action = true,
    offer_referral = true,
    publish_summary = true,
    compel_evidence = true,
    execute_intervention = true,
    determine_legal_status = true
}

local PROHIBITED = {
    compel_evidence = true,
    execute_intervention = true,
    determine_legal_status = true
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

local function assess_launch(requirements)
    local allowed = {}
    for _, name in ipairs(REQUIREMENTS) do allowed[name] = true end
    fields(requirements, allowed, "requirements")

    local result = M.metadata()
    result.gaps = {}
    for _, name in ipairs(REQUIREMENTS) do
        local value = choice(requirements[name], TRI, "requirements." .. name)
        if value ~= "established" then
            result.gaps[#result.gaps + 1] = {
                requirement = name,
                status = value
            }
        end
    end

    result.mode = #result.gaps == 0
        and "eligible_for_separate_launch_authorization"
        or "synthetic_exercises_only"
    result.scope =
        "Supplied checklist only; no operator, funding, legal agreement, "
        .. "security, accessibility, or launch authority verified."
    return result
end

function M.launch_check(requirements)
    return protect(function() return assess_launch(requirements) end)
end

function M.route(input)
    return protect(function()
        fields(input, {
            requirements = true,
            action = true,
            organization_participates = true,
            scope_matches = true,
            reviewer_independent = true,
            disclosure_permission = true,
            publication_review = true
        }, "request")

        local launch = assess_launch(input.requirements)
        local action = choice(input.action, ACTIONS, "action")
        local participation = choice(input.organization_participates, TRI,
            "organization_participates")
        local scope = choice(input.scope_matches, TRI, "scope_matches")
        local independent = choice(input.reviewer_independent, TRI,
            "reviewer_independent")
        local disclosure = choice(input.disclosure_permission, TRI,
            "disclosure_permission")
        local publication = choice(input.publication_review, TRI,
            "publication_review")

        local result = M.metadata()
        result.action = action
        result.execution_authority = "none"
        result.direct_participation =
            "Do not treat an institutional gap as participant ineligibility"

        if PROHIBITED[action] then
            result.route = "outside_charter_authority"
        elseif launch.mode == "synthetic_exercises_only" then
            result.route = "do_not_start_real_case_processing"
        elseif action == "receive_concern" then
            result.route = "eligible_for_accessible_scoped_intake"
        elseif action == "offer_referral" then
            result.route = "offer_without_transferring_case_material"
            if disclosure == "established" then
                result.route = "eligible_for_separate_authorized_referral"
            end
        elseif action == "publish_summary" then
            result.route =
                disclosure == "established" and publication == "established"
                and "eligible_for_separate_publication_authorization"
                or "do_not_publish_resolve_disclosure_and_review"
        elseif scope ~= "established" then
            result.route = "clarify_scope_without_promising_jurisdiction"
        elseif participation ~= "established" then
            result.route = "voluntary_invitation_or_explained_limitation"
        elseif action == "review_commitment"
            or action == "recommend_action" then
            result.route = independent == "established"
                and "eligible_for_nonbinding_review_or_recommendation"
                or "independent_review_assignment_required"
        else
            result.route = "eligible_for_bounded_voluntary_coordination"
        end

        result.scope =
            "Policy routing from supplied assertions only; no intake, "
            .. "disclosure, referral, publication, or decision executed."
        return result
    end)
end

local function fixture()
    local requirements = {}
    for _, name in ipairs(REQUIREMENTS) do
        requirements[name] = "established"
    end
    return {
        requirements = requirements,
        action = "review_commitment",
        organization_participates = "established",
        scope_matches = "established",
        reviewer_independent = "established",
        disclosure_permission = "unknown",
        publication_review = "unknown"
    }
end

function M.self_test()
    local input = fixture()
    assert(assert(M.route(input)).route ==
        "eligible_for_nonbinding_review_or_recommendation")

    input.requirements.funded_capacity = "unknown"
    assert(assert(M.route(input)).route ==
        "do_not_start_real_case_processing")

    input = fixture()
    input.action = "execute_intervention"
    assert(assert(M.route(input)).route == "outside_charter_authority")

    input = fixture()
    input.action = "receive_concern"
    input.organization_participates = "not_established"
    assert(assert(M.route(input)).route ==
        "eligible_for_accessible_scoped_intake")

    input = fixture()
    input.action = "publish_summary"
    assert(assert(M.route(input)).route ==
        "do_not_publish_resolve_disclosure_and_review")

    input = fixture()
    input.reviewer_independent = "unknown"
    assert(assert(M.route(input)).route ==
        "independent_review_assignment_required")

    return true
end

return M
