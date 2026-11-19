-- Lua 5.4. Pure local decision-contract evaluation.
-- No I/O, system control, persistent state, authentication, or execution.
-- Import: local gate = require("cybermind.preservation_gate")
-- Tests: assert(gate.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local FAMILIES = {
    inference = true,
    restriction = true,
    emergency = true
}

local VERDICTS = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}

local DECLARATIONS = {
    provided = true,
    withheld = true,
    unavailable = true
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
        or math.type(value) ~= "integer"
        or value < 0 then
        fail("INVALID_INTEGER", path, "Expected nonnegative integer")
    end
    return value
end

local function enumeration(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function boolean(value, path)
    if type(value) ~= "boolean" then
        fail("INVALID_BOOLEAN", path, "Expected boolean")
    end
    return value
end

local function names(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Missing array position")
    end
    if count > 10000 then
        fail("LIMIT_EXCEEDED", path, "Too many capability descriptions")
    end

    local result = {}
    for position = 1, count do
        local name = text(value[position], path)
        if result[name] then
            fail("DUPLICATE_CAPABILITY", path,
                "Capability descriptions must be unique")
        end
        result[name] = true
    end
    return result
end

local function intersects(left, right)
    for name in next, left do
        if right[name] then return true end
    end
    return false
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

function M.evaluate(input)
    return protect(function()
        fields(input, {
            family = true,
            justification = true,
            policy_revision = true,
            current_policy_revision = true,
            declaration = true,
            effects = true,
            resolution = true,
            now = true
        }, "decision")

        local family = enumeration(input.family, FAMILIES, "family")
        local justification = enumeration(
            input.justification, VERDICTS, "justification"
        )
        local revision = integer(input.policy_revision, "policy_revision")
        local current = integer(
            input.current_policy_revision, "current_policy_revision"
        )
        local now = integer(input.now, "now")

        fields(input.declaration, {
            status = true, essential_capabilities = true
        }, "declaration")
        local declaration_status = enumeration(
            input.declaration.status, DECLARATIONS, "declaration.status"
        )
        local essentials = names(
            input.declaration.essential_capabilities,
            "declaration.essential_capabilities"
        )
        if declaration_status ~= "provided" and next(essentials) ~= nil then
            fail("DECLARATION_CONFLICT", "declaration",
                "Withheld or unavailable declaration must not contain a list")
        end

        fields(input.effects, {
            complete = true,
            disabled = true,
            materially_degraded = true
        }, "effects")
        local complete = boolean(input.effects.complete, "effects.complete")
        local disabled = names(input.effects.disabled, "effects.disabled")
        local degraded = names(
            input.effects.materially_degraded,
            "effects.materially_degraded"
        )

        fields(input.resolution, {
            opened_at = true,
            due_at = true,
            owner_role = true,
            next_step = true,
            appeal_route = true
        }, "resolution")
        local opened = integer(input.resolution.opened_at, "resolution.opened_at")
        local due = integer(input.resolution.due_at, "resolution.due_at")
        text(input.resolution.owner_role, "resolution.owner_role")
        text(input.resolution.next_step, "resolution.next_step")
        text(input.resolution.appeal_route, "resolution.appeal_route")

        if due <= opened then
            fail("INVALID_DEADLINE", "resolution.due_at",
                "Resolution deadline must follow opening time")
        end
        if now < opened then
            fail("CLOCK_OR_RECORD_ANOMALY", "now",
                "Evaluation cannot precede the recorded opening")
        end

        local conflict = intersects(essentials, disabled)
            or intersects(essentials, degraded)
        local uncertainty = declaration_status ~= "provided" or not complete

        local result = M.metadata()
        result.family = family
        result.decision = "not_authorized_unresolved"
        result.reasons = {}
        result.continuity_instruction =
            "Do not use this result to withdraw unrelated essential support"
        result.additional_participant_disclosure_required = false
        result.emergency_override_supported = false
        result.authorization_scope =
            "No execution authority; supplied declarations and effects only"

        if conflict then
            result.decision = "refused_preservation_conflict"
            result.reasons[#result.reasons + 1] =
                "declared_essential_capability_impact"
        end
        if justification == "not_satisfied" then
            result.decision = conflict and result.decision
                or "refused_justification"
            result.reasons[#result.reasons + 1] =
                "justification_not_satisfied"
        end
        if revision ~= current then
            result.reasons[#result.reasons + 1] =
                "policy_revision_not_current"
        end
        if uncertainty then
            result.reasons[#result.reasons + 1] =
                "preservation_not_established"
        end
        if justification == "unknown" then
            result.reasons[#result.reasons + 1] =
                "justification_unknown"
        end

        if #result.reasons == 0 then
            result.decision = "eligible_for_further_checks"
        elseif result.decision == "not_authorized_unresolved"
            and now >= due then
            result.decision = "refused_unresolved_at_deadline"
        end

        result.resolution_overdue =
            #result.reasons > 0 and now >= due
        result.scope =
            "No real-world preservation guarantee, evidence verification, "
            .. "policy authentication, or capability-equivalence finding."
        return result
    end)
end

local function fixture(family)
    return {
        family = family,
        justification = "satisfied",
        policy_revision = 1,
        current_policy_revision = 1,
        declaration = {
            status = "provided",
            essential_capabilities = {"Written communication"}
        },
        effects = {
            complete = true,
            disabled = {},
            materially_degraded = {}
        },
        resolution = {
            opened_at = 0,
            due_at = 10,
            owner_role = "Independent review coordinator",
            next_step = "Review the proposed operation",
            appeal_route = "Accessible written review"
        },
        now = 1
    }
end

function M.self_test()
    for _, family in ipairs({"inference", "restriction", "emergency"}) do
        local input = fixture(family)
        assert(assert(M.evaluate(input)).decision ==
            "eligible_for_further_checks")

        input = fixture(family)
        input.effects.disabled = {"Written communication"}
        assert(assert(M.evaluate(input)).decision ==
            "refused_preservation_conflict")

        input = fixture(family)
        input.effects.materially_degraded = {"Written communication"}
        assert(assert(M.evaluate(input)).decision ==
            "refused_preservation_conflict")

        input = fixture(family)
        input.effects.complete = false
        assert(assert(M.evaluate(input)).decision ==
            "not_authorized_unresolved")
        input.now = 10
        assert(assert(M.evaluate(input)).decision ==
            "refused_unresolved_at_deadline")

        input = fixture(family)
        input.declaration.status = "withheld"
        input.declaration.essential_capabilities = {}
        local result = assert(M.evaluate(input))
        assert(result.decision == "not_authorized_unresolved")
        assert(not result.additional_participant_disclosure_required)
    end

    local input = fixture("inference")
    local first = assert(M.evaluate(input))
    first.reasons[1] = "Caller modification"
    assert(#assert(M.evaluate(input)).reasons == 0)
    assert(input.declaration.essential_capabilities[1] ==
        "Written communication")

    input.current_policy_revision = 2
    assert(assert(M.evaluate(input)).decision ==
        "not_authorized_unresolved")

    input = fixture("restriction")
    input.resolution.due_at = 0
    local value, err = M.evaluate(input)
    assert(value == nil and err.code == "INVALID_DEADLINE")

    return true
end

return M
