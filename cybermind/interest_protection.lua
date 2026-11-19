-- Lua 5.4.
-- Pure procedural safeguard mapping; no ranking or legal-status determination.
-- No I/O, private-system access, identity inference, or external actions.
-- Import: local protection = require("cybermind.interest_protection")
-- Tests: assert(protection.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {yes = true, no = true, unknown = true}
local PROFILES = {
    living = true,
    sentient = true,
    sapient = true,
    distributed = true
}

local INTEREST_DUTIES = {
    communication = {
        "offer_accessible_communication",
        "provide_expression_correction_route"
    },
    privacy = {
        "limit_information_to_declared_purpose",
        "avoid_unnecessary_sensitive_disclosure"
    },
    continuity = {
        "assess_interruption_and_transition_options",
        "identify_responsible_support_roles"
    },
    authorship = {
        "distinguish_candidate_from_approved_expression",
        "preserve_user_control_over_release"
    },
    possible_welfare = {
        "document_evidence_and_alternative_explanations",
        "review_proportionate_bounded_precautions"
    },
    ecological = {
        "assess_lifecycle_and_community_effects",
        "consider_repair_and_restoration_options"
    }
}

local BASELINE = {
    "acknowledge_the_concern",
    "provide_understandable_reasons",
    "offer_accessible_correction_or_challenge",
    "avoid_retaliation_for_participation"
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
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function enum_array(value, vocabulary, path, maximum)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, highest = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        highest = math.max(highest, key)
    end
    if count ~= highest or count > maximum then
        fail("INVALID_ARRAY_SIZE", path, "Array is sparse or exceeds limit")
    end

    local result, seen = {}, {}
    for position = 1, count do
        local item = choice(value[position], vocabulary, path)
        if seen[item] then
            fail("DUPLICATE_ENTRY", path, "Repeated vocabulary entry")
        end
        seen[item] = true
        result[#result + 1] = item
    end
    table.sort(result)
    return result
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

function M.assess(input)
    return protect(function()
        fields(input, {
            scope_note = true,
            interests = true,
            research_profiles = true,
            essential_capability_affected = true,
            private_information_exposed = true,
            irreversible_effect = true,
            restriction_proposed = true,
            restriction_justification = true
        }, "assessment")

        text(input.scope_note, "scope_note")
        local interests = enum_array(
            input.interests, INTEREST_DUTIES, "interests", 6
        )
        local profiles = {}
        if input.research_profiles ~= nil then
            profiles = enum_array(
                input.research_profiles, PROFILES, "research_profiles", 4
            )
        end

        local essential = choice(input.essential_capability_affected,
            TRI, "essential_capability_affected")
        local exposure = choice(input.private_information_exposed,
            TRI, "private_information_exposed")
        local irreversible = choice(input.irreversible_effect,
            TRI, "irreversible_effect")

        if type(input.restriction_proposed) ~= "boolean" then
            fail("INVALID_BOOLEAN", "restriction_proposed", "Expected boolean")
        end

        local justification = choice(input.restriction_justification, {
            satisfied = true,
            not_satisfied = true,
            unknown = true,
            not_applicable = true
        }, "restriction_justification")

        if input.restriction_proposed and justification == "not_applicable" then
            fail("JUSTIFICATION_REQUIRED", "restriction_justification",
                "A proposed restriction requires an explicit assessment")
        end
        if not input.restriction_proposed
            and justification ~= "not_applicable" then
            fail("INAPPLICABLE_JUSTIFICATION", "restriction_justification",
                "Use not_applicable when no restriction is proposed")
        end

        local duty_set = {}
        for _, duty in ipairs(BASELINE) do duty_set[duty] = true end
        for _, interest in ipairs(interests) do
            for _, duty in ipairs(INTEREST_DUTIES[interest]) do
                duty_set[duty] = true
            end
        end

        if essential == "yes" then
            duty_set["apply_essential_capability_preservation_review"] = true
        elseif essential == "unknown" then
            duty_set["clarify_effects_without_compelled_private_inventory"] = true
        end

        if exposure == "yes" then
            duty_set["review_containment_and_appropriate_remedy"] = true
        elseif exposure == "unknown" then
            duty_set["assess_disclosure_paths_before_new_release"] = true
        end

        if irreversible ~= "no" then
            duty_set["review_reversible_and_less_harmful_alternatives"] = true
            duty_set["record_irreversibility_and_residual_uncertainty"] = true
        end

        local result = M.metadata()
        result.interests = interests
        result.research_profiles = profiles
        result.duties = {}
        for duty in next, duty_set do
            result.duties[#result.duties + 1] = duty
        end
        table.sort(result.duties)

        if not input.restriction_proposed then
            result.restriction_route = "no_restriction_requested"
        elseif justification ~= "satisfied" then
            result.restriction_route = "not_cleared_under_supplied_justification"
        elseif essential ~= "no" or exposure ~= "no"
            or irreversible ~= "no" then
            result.restriction_route = "additional_consequence_review_required"
        else
            result.restriction_route = "eligible_for_separate_authority_checks"
        end

        result.rank = "not_computed"
        result.legal_status = "not_determined"
        result.execution_authority = "none"
        result.scope =
            "Proposed safeguard mapping from supplied interests and effects; "
            .. "no identity, consciousness, entitlement, or legal determination."
        return result
    end)
end

function M.self_test()
    local input = {
        scope_note = "Synthetic communication-continuity scenario",
        interests = {"communication", "continuity"},
        research_profiles = {"living"},
        essential_capability_affected = "yes",
        private_information_exposed = "no",
        irreversible_effect = "unknown",
        restriction_proposed = true,
        restriction_justification = "satisfied"
    }

    local first = assert(M.assess(input))
    assert(first.restriction_route == "additional_consequence_review_required")

    input.research_profiles = {"living", "sentient", "sapient", "distributed"}
    local second = assert(M.assess(input))
    assert(#first.duties == #second.duties)
    for position, duty in ipairs(first.duties) do
        assert(duty == second.duties[position])
    end

    input.restriction_justification = "unknown"
    assert(assert(M.assess(input)).restriction_route ==
        "not_cleared_under_supplied_justification")

    second.duties[1] = "Caller edit"
    assert(assert(M.assess(input)).duties[1] ~= "Caller edit")

    input.interests = {"communication", "communication"}
    local value, err = M.assess(input)
    assert(value == nil and err.code == "DUPLICATE_ENTRY")

    return true
end

return M
