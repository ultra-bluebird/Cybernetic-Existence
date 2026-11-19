-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Attribution is credit and metadata only.
-- No identity, consent, capability, or execution authority is established.
--
-- Pure research reference. No network, file, device, or persistence access.
-- Not an independent oracle; not a cryptographic verifier.
-- Lua 5.1+.

local M = {}

local MAX_ITEMS = 128
local MAX_INTEGER = 1000000000
local DIMENSIONS = {
    "identity", "health", "location", "linkability", "inner_state"
}

local function plain(value)
    assert(type(value) == "table"
        and getmetatable(value) == nil, "plain table required")
end

local function text(value)
    assert(type(value) == "string"
        and #value > 0 and #value <= 128
        and value:match("%S")
        and not value:find("[%z\1-\31\127]"),
        "bounded text required")
    return value
end

local function integer(value)
    assert(type(value) == "number"
        and value == value
        and value >= 0 and value <= MAX_INTEGER
        and value % 1 == 0, "bounded integer required")
    return value
end

local function boolean(value)
    assert(type(value) == "boolean", "explicit boolean required")
    return value
end

local function length(array)
    plain(array)
    local count, maximum = 0, 0

    for key in next, array do
        count = count + 1
        assert(count <= MAX_ITEMS
            and type(key) == "number"
            and key >= 1 and key <= MAX_ITEMS
            and key % 1 == 0, "invalid array")
        maximum = math.max(maximum, key)
    end

    assert(count == maximum, "array gaps prohibited")
    return count
end

local function enum(value, values)
    assert(values[value] == true, "unrecognized enum")
end

local function vector(value)
    plain(value)
    local count = 0
    local allowed = {}
    local copy = {}

    for i = 1, #DIMENSIONS do
        allowed[DIMENSIONS[i]] = true
    end

    for key in next, value do
        assert(allowed[key], "unknown dimension")
        count = count + 1
    end
    assert(count == #DIMENSIONS, "complete vector required")

    for i = 1, #DIMENSIONS do
        local key = DIMENSIONS[i]
        copy[key] = integer(value[key])
    end

    return copy
end

local function dominates(left, right)
    local strict = false

    for i = 1, #DIMENSIONS do
        local key = DIMENSIONS[i]
        if left[key] > right[key] then
            return false
        end
        if left[key] < right[key] then
            strict = true
        end
    end

    return strict
end

local function protect(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return {status = "malformed_input"}
end

function M.pareto(candidates)
    return protect(function()
        local n = length(candidates)
        local compiled, labels = {}, {}

        for i = 1, n do
            plain(candidates[i])
            local label = text(candidates[i].label)
            assert(not labels[label], "duplicate candidate label")
            labels[label] = true

            compiled[i] = {
                label = label,
                exposure = vector(candidates[i].exposure)
            }
        end

        local front = {}
        for i = 1, n do
            local dominated = false

            for j = 1, n do
                if i ~= j and dominates(
                    compiled[j].exposure, compiled[i].exposure
                ) then
                    dominated = true
                    break
                end
            end

            if not dominated then
                front[#front + 1] = compiled[i].label
            end
        end

        table.sort(front)

        return {
            status = "computed",
            candidates = front,
            display_order_is_selection_policy = false
        }
    end)
end

function M.eligibility(spec)
    return protect(function()
        plain(spec)

        enum(spec.purpose, {
            permitted_in_scope = true,
            prohibited = true,
            unresolved = true
        })
        enum(spec.permission, {
            granted = true,
            absent = true,
            unknown = true
        })
        enum(spec.evidence, {
            adequate = true,
            inadequate = true,
            unknown = true
        })

        local authorization_ok = spec.permission == "granted"
        local evidence_ok = spec.evidence == "adequate"
        local purpose_ok = spec.purpose == "permitted_in_scope"

        return {
            status = "assessed",
            purpose_finding = spec.purpose,
            authorization_finding = spec.permission,
            evidence_finding = spec.evidence,
            eligible = purpose_ok and authorization_ok and evidence_ok,
            eligibility_is_execution_authorization = false
        }
    end)
end

function M.mutation_score(mutants)
    return protect(function()
        local n = length(mutants)
        local denominator, killed, excluded = 0, 0, 0
        local labels = {}

        for i = 1, n do
            local item = mutants[i]
            plain(item)
            local label = text(item.label)
            assert(not labels[label], "duplicate mutant label")
            labels[label] = true

            boolean(item.equivalent)
            boolean(item.killed)

            if item.equivalent then
                text(item.equivalence_justification)
                excluded = excluded + 1
            else
                denominator = denominator + 1
                if item.killed then
                    killed = killed + 1
                end
            end
        end

        return {
            status = denominator == 0 and "not_assessable" or "computed",
            score = denominator > 0 and killed / denominator or nil,
            evaluated_non_equivalent = denominator,
            killed = killed,
            declared_equivalent_excluded = excluded,
            equivalence_independently_verified = false
        }
    end)
end

function M.rubric(criteria)
    return protect(function()
        local n = length(criteria)
        local passed, failed, unassessed = 0, 0, 0
        local labels = {}

        for i = 1, n do
            local item = criteria[i]
            plain(item)
            local label = text(item.label)
            assert(not labels[label], "duplicate criterion label")
            labels[label] = true

            assert(item.pass_value == 0 or item.pass_value == 1,
                "binary pass value required")

            if item.value == "not_assessed" then
                unassessed = unassessed + 1
            else
                assert(item.value == 0 or item.value == 1,
                    "binary value or not_assessed required")
                if item.value == item.pass_value then
                    passed = passed + 1
                else
                    failed = failed + 1
                end
            end
        end

        local status
        if n == 0 then
            status = "not_assessed"
        elseif failed > 0 then
            status = "criteria_not_met"
        elseif unassessed > 0 then
            status = "assessment_incomplete"
        else
            status = "declared_criteria_met"
        end

        return {
            status = status,
            passed = passed,
            failed = failed,
            unassessed = unassessed,
            independent_assessment_established = false
        }
    end)
end

function M.self_test()
    local checks = 0

    local function expect(condition)
        assert(condition, "reference acceptance test failed")
        checks = checks + 1
    end

    local function v(a, b)
        return {
            identity = a, health = b, location = 0,
            linkability = 0, inner_state = 0
        }
    end

    local result = M.pareto({
        {label = "equal_a", exposure = v(1, 1)},
        {label = "equal_b", exposure = v(1, 1)},
        {label = "dominated", exposure = v(2, 2)}
    })
    expect(result.status == "computed")
    expect(#result.candidates == 2)

    local incomparable = M.pareto({
        {label = "a", exposure = v(1, 3)},
        {label = "b", exposure = v(3, 1)}
    })
    expect(#incomparable.candidates == 2)

    local gate = M.eligibility({
        purpose = "permitted_in_scope",
        permission = "absent",
        evidence = "adequate"
    })
    expect(not gate.eligible)
    expect(gate.evidence_finding == "adequate")

    gate = M.eligibility({
        purpose = "permitted_in_scope",
        permission = "granted",
        evidence = "inadequate"
    })
    expect(not gate.eligible)
    expect(gate.purpose_finding == "permitted_in_scope")

    local score = M.mutation_score({
        {label = "unsafe_permission", equivalent = false, killed = true},
        {label = "missed_gate", equivalent = false, killed = false},
        {
            label = "equivalent_reordering",
            equivalent = true,
            killed = false,
            equivalence_justification = "synthetic assertion only"
        }
    })
    expect(score.score == 0.5)

    local rubric = M.rubric({
        {label = "rights_alignment", value = 1, pass_value = 1},
        {label = "harm_risk", value = 0, pass_value = 0}
    })
    expect(rubric.status == "declared_criteria_met")

    rubric = M.rubric({
        {label = "accessibility", value = "not_assessed", pass_value = 1}
    })
    expect(rubric.status == "assessment_incomplete")

    expect(M.pareto({
        {label = "bad", exposure = {}}
    }).status == "malformed_input")

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic reference tests",
        independent_oracle = false,
        formal_proof = false
    }
end

return M
