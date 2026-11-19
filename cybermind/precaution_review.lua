-- Lua 5.4.
-- Pure workshop decision support; no external actions or system control.
-- Import: local precaution = require("cybermind.precaution_review")
-- Tests: assert(precaution.self_test())
--
-- Loss values must share a declared, justified comparison scale.
-- Scenario losses are supplied assumptions, not measured probabilities.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local DIMENSIONS = {
    "physical",
    "informational",
    "relational",
    "temporal",
    "institutional"
}

local REVERSIBILITY = {
    reversible = true,
    difficult_to_reverse = true,
    irreversible = true,
    unknown = true
}

local TRI = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
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

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function array_length(value, path, limit)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array contains missing positions")
    end
    if count > limit then
        fail("LIMIT_EXCEEDED", path, "Collection exceeds limit")
    end
    return count
end

local function loss(value, path)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < 0 or value > 1000000000000 then
        fail("INVALID_LOSS", path,
            "Expected finite nonnegative loss within configured bound")
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

function M.compare(input)
    return protect(function()
        fields(input, {
            loss_scale_note = true,
            uncertainty_note = true,
            scenarios = true,
            actions = true
        }, "comparison")
        text(input.loss_scale_note, "loss_scale_note")
        text(input.uncertainty_note, "uncertainty_note")

        local scenario_count = array_length(input.scenarios, "scenarios", 256)
        if scenario_count == 0 then
            fail("EMPTY_SCENARIOS", "scenarios", "At least one scenario is needed")
        end

        local scenarios, scenario_set = {}, {}
        for position = 1, scenario_count do
            local name = text(input.scenarios[position], "scenarios")
            if scenario_set[name] then
                fail("DUPLICATE_SCENARIO", "scenarios", "Repeated scenario name")
            end
            scenario_set[name] = true
            scenarios[#scenarios + 1] = name
        end
        table.sort(scenarios)

        local action_count = array_length(input.actions, "actions", 128)
        local result = M.metadata()
        result.excluded = {}
        result.comparison = {}
        result.minimax_candidates = {}
        result.authorization = "none"

        local eligible, action_names = {}, {}

        for position = 1, action_count do
            local source = input.actions[position]
            local path = "actions[" .. position .. "]"
            fields(source, {
                name = true,
                safeguards = true,
                role_reversal = true,
                role_reversal_note = true,
                irreversibility = true,
                enhanced_review = true,
                losses = true
            }, path)

            local name = text(source.name, path .. ".name")
            if action_names[name] then
                fail("DUPLICATE_ACTION", path, "Repeated action name")
            end
            action_names[name] = true

            local safeguards = choice(source.safeguards, TRI,
                path .. ".safeguards")
            local reversal = choice(source.role_reversal, {
                consistent = true,
                difference_justified = true,
                unresolved = true
            }, path .. ".role_reversal")
            text(source.role_reversal_note, path .. ".role_reversal_note")

            local allowed = {}
            for _, dimension in ipairs(DIMENSIONS) do allowed[dimension] = true end
            fields(source.irreversibility, allowed, path .. ".irreversibility")

            local enhanced_needed = false
            local profile = {}
            for _, dimension in ipairs(DIMENSIONS) do
                local value = choice(source.irreversibility[dimension],
                    REVERSIBILITY, path .. ".irreversibility." .. dimension)
                profile[dimension] = value
                if value ~= "reversible" then enhanced_needed = true end
            end

            local enhanced = choice(source.enhanced_review, {
                completed = true,
                not_completed = true,
                unknown = true
            }, path .. ".enhanced_review")

            fields(source.losses, scenario_set, path .. ".losses")
            local losses = {}
            for _, scenario in ipairs(scenarios) do
                losses[scenario] = loss(source.losses[scenario],
                    path .. ".losses." .. scenario)
            end

            local reasons = {}
            if safeguards ~= "satisfied" then
                reasons[#reasons + 1] = "safeguards:" .. safeguards
            end
            if reversal == "unresolved" then
                reasons[#reasons + 1] = "role_reversal_unresolved"
            end
            if enhanced_needed and enhanced ~= "completed" then
                reasons[#reasons + 1] = "enhanced_review_not_completed"
            end

            if #reasons > 0 then
                result.excluded[#result.excluded + 1] = {
                    name = name,
                    reasons = reasons,
                    irreversibility = profile
                }
            else
                eligible[#eligible + 1] = {
                    name = name,
                    losses = losses,
                    irreversibility = profile
                }
            end
        end

        table.sort(eligible, function(a, b) return a.name < b.name end)
        table.sort(result.excluded, function(a, b) return a.name < b.name end)

        if #eligible == 0 then
            result.status = "no_comparable_action_under_supplied_reviews"
            result.scope = "No action authorized; resolve review and scope gaps"
            return result
        end

        local best_by_scenario = {}
        for _, scenario in ipairs(scenarios) do
            local best = math.huge
            for _, action in ipairs(eligible) do
                best = math.min(best, action.losses[scenario])
            end
            best_by_scenario[scenario] = best
        end

        local minimum_regret = math.huge
        for _, action in ipairs(eligible) do
            local maximum_regret = 0
            local scenario_regrets = {}
            for _, scenario in ipairs(scenarios) do
                local regret = action.losses[scenario]
                    - best_by_scenario[scenario]
                scenario_regrets[scenario] = regret
                maximum_regret = math.max(maximum_regret, regret)
            end
            minimum_regret = math.min(minimum_regret, maximum_regret)
            result.comparison[#result.comparison + 1] = {
                name = action.name,
                maximum_regret = maximum_regret,
                scenario_regrets = scenario_regrets,
                irreversibility = action.irreversibility
            }
        end

        for _, action in ipairs(result.comparison) do
            if action.maximum_regret == minimum_regret then
                result.minimax_candidates[#result.minimax_candidates + 1] =
                    action.name
            end
        end

        result.status = "scenario_comparison_complete"
        result.scope =
            "Decision support under supplied scenarios, losses, and review "
            .. "assertions only; no consciousness finding, evidence "
            .. "authentication, preservation guarantee, or action authority."
        return result
    end)
end

function M.self_test()
    local function action(name, first, second)
        local profile = {}
        for _, dimension in ipairs(DIMENSIONS) do
            profile[dimension] = "reversible"
        end
        return {
            name = name,
            safeguards = "satisfied",
            role_reversal = "consistent",
            role_reversal_note = "Synthetic workshop assertion",
            irreversibility = profile,
            enhanced_review = "not_completed",
            losses = {["Scenario A"] = first, ["Scenario B"] = second}
        }
    end

    local input = {
        loss_scale_note = "Synthetic common loss scale; not measured welfare",
        uncertainty_note = "Two hypothetical cases; no probabilities assigned",
        scenarios = {"Scenario A", "Scenario B"},
        actions = {
            action("Bounded precaution", 2, 2),
            action("No added precaution", 0, 5)
        }
    }

    local result = assert(M.compare(input))
    assert(result.minimax_candidates[1] == "Bounded precaution")
    assert(result.comparison[1].maximum_regret == 2)

    input.actions[1].irreversibility.informational = "unknown"
    result = assert(M.compare(input))
    assert(#result.excluded == 1)
    assert(result.excluded[1].name == "Bounded precaution")

    input.actions[2].safeguards = "unknown"
    result = assert(M.compare(input))
    assert(result.status == "no_comparable_action_under_supplied_reviews")

    return true
end

return M
